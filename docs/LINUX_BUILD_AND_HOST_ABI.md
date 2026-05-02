# Linux Build and Host ABI Notes

## Goal

Make the ARM64 guest build usable on a Linux AArch64 host without scattering
Darwin-only assumptions through the runtime.

## Current Linux build

Verified on this host with:

```bash
cd /workspace/projects/ish-arm64
CC=clang meson setup build-arm64-linux -Dguest_arch=arm64 --buildtype=release
ninja -C build-arm64-linux
```

Result:

- host binary: `build-arm64-linux/ish`
- fakefs helper: `build-arm64-linux/tools/fakefsify`
- SDL/VNC harness: `build-linux-harness/tools/ish-sdl-vnc`

## Smoke test

Verified runnable on Linux with realfs:

```bash
cd /workspace/projects/ish-arm64
./build-arm64-linux/ish -r / /bin/echo hello
```

Observed:

- stdout: `hello`
- process exit: `0`

---

## Host ABI seams now made explicit

The Linux port needed two host-ABI boundaries to be made explicit instead of
relying on Darwin-specific structure layouts and APIs.

## 1. AArch64 signal/ucontext ABI

File:

- `platform/host_context_aarch64.h`

This centralizes host signal-context access for JIT crash recovery:

- general register reads (`x0..x30`)
- `pc`, `sp`, `lr`
- patching `pc`/`sp` to redirect back into the fiber exit path
- extracting ESR when available

### Why this matters

Previously `main.c` directly assumed Darwin’s `ucontext_t` layout:

- `uc_mcontext->__ss.__x[...]`
- `uc_mcontext->__ss.__pc`
- `uc_mcontext->__ss.__sp`
- `uc_mcontext->__es.__esr`

That does not compile on Linux.

Linux AArch64 uses a different ABI:

- `uc_mcontext.regs[...]`
- `uc_mcontext.pc`
- `uc_mcontext.sp`
- ESR lives in the reserved signal-frame records (`ESR_MAGIC`), not a Darwin-style field

The new header keeps `main.c` independent of those layout details.

## 2. Host filesystem/fd-path ABI in fakefs bind mounts

File:

- `fs/fake.c`

This now uses small host-abstraction helpers for:

- stat timestamp extraction
- root-fd → absolute-path lookup

### Why this matters

The fork previously assumed Apple-only APIs and stat field names:

- `F_GETPATH`
- `st_atimespec`, `st_mtimespec`, `st_ctimespec`

Linux needs:

- `/proc/self/fd/<n>` + `readlink()` for fd path lookup
- `st_atim`, `st_mtim`, `st_ctim`

The helpers keep those differences localized.

---

## ARM64 JIT memory-fault retry ABI

Files:

- `asbestos/frame.h`
- `asbestos/guest-arm64/gen.c`
- `asbestos/guest-arm64/gadgets-aarch64/entry.S`
- `asbestos/guest-arm64/gadgets-aarch64/gadgets.h`
- `main.c`

The ARM64 backend now has an explicit per-frame retry-PC slot for faultable
JIT memory instructions:

- `fiber_frame::jit_saved_pc` stores the guest PC of the current load/store.
- `gadget_set_jit_saved_pc` is emitted before ARM64 load/store gadgets.
- async host `SIGSEGV`/`SIGBUS` recovery restores `cpu->pc` from that slot;
  the older thread-local block-start PC remains only a fallback.
- TLB miss and cross-page memory-fault exits that return `INT_GPF` also restore
  `cpu->pc` from the same slot before leaving the fiber.

This is required because a memory fault can happen after earlier gadgets in the
same block have already changed guest registers. Retrying at the block start can
re-run those side effects. The concrete failure this fixed was Bun/JSC's
freelist fill loop: a fault at `4897440: str x10, [x11]` could restart at
`4897430: madd x11, x1, x11, x1` after `4897438: mov x11, x8` had changed
`x11` into the loop pointer, producing a bogus high freelist `next` pointer.

Validation after the fix:

- `make build-arm64-linux-all` passes.
- 50 consecutive minimal Bun local `file:` install repro runs passed.
- staged runtime coverage initially improved to **18 / 20 passing**; after the
  JavaScriptCore GC shims below it is **20 / 20 passing**.


## JavaScriptCore GC compatibility shims

File:

- `kernel/exec.c`

The ARM64 guest now injects:

```text
JSC_numberOfGCMarkers=1
JSC_useConcurrentGC=0
```

unless the guest process already provided those variables. This keeps
JavaScriptCore GC enabled but avoids the parallel marker thread suspension and
concurrent GC paths that currently do not fit iSH's signal/timer delivery model.

The observed hang was:

- `bun -e "console.log(1)"`, `bun run index.ts`, and `bun test` stalled after
  the allocator/freelist fix;
- `setTimeout` and external `Bun.serve` clients also stalled until concurrent GC
  was disabled;
- strace showed one JSC thread repeatedly using `tkill(..., SIGPWR)` to suspend
  another marker thread;
- the target thread repeatedly acknowledged enough to wake a semaphore, then
  returned from the signal handler and re-entered `futex_wait`;
- setting `JSC_numberOfGCMarkers=1` plus `JSC_useConcurrentGC=0` made
  `bun -e`, timers, TypeScript run, `bun test`, `bun build`, and a minimal
  `Bun.serve` smoke pass while preserving GC.

These are compatibility shims, not a final model for full parallel/concurrent
JSC GC. The underlying future cleanup is to make signal-delivered ucontexts,
thread-suspension behavior, and timer/event-loop interaction close enough to
native Linux that JSC's multi-marker/concurrent GC paths can run unmodified.

## ARM64 signal ABI fixes from the JSC trace

Files:

- `kernel/signal.h`
- `kernel/signal.c`
- `kernel/arch/arm64/calls.c`

The same trace exposed three signal ABI issues that are now fixed:

- ARM64 `siginfo_t` now includes the 64-bit Linux padding word before the
  `_sifields` union, so fields such as `si_pid` and `si_uid` are at the Linux
  offsets expected by signal handlers.
- `tkill` and `tgkill` now deliver `SI_TKILL` instead of plain `SI_USER`.
- ARM64 syscall 240 (`rt_tgsigqueueinfo`) is no longer miswired to
  `sys_rt_sigreturn`; unsupported use now follows the normal syscall-stub path
  instead of corrupting CPU state.

## Locking note exposed by precise retry

Files:

- `util/sync.h`
- `kernel/memory.c`
- `asbestos/asbestos.c`

The Linux/glibc `pthread_rwlock` configuration is writer-preferred. During JIT
page-fault handling, a thread can release a read lock to attempt a write-lock
upgrade and then fail `trywrlock` because another thread is queued for write. If
it immediately blocks in `rdlock`, it can prevent the queued writer from making
progress and deadlock retry paths.

The current rule is:

- after a failed JIT write-lock upgrade, reacquire read permission with
  try-read/yield rather than blocking behind a queued writer;
- do not block on Asbestos jetsam cleanup while `task_run_current` is still
  holding `mem->lock` for read.

This keeps the precise retry path from turning allocator/page-fault contention
into a host rwlock deadlock.

---


## Directory entry type ABI

Files:

- `fs/fd.h`
- `fs/dir.c`
- `fs/real.c`
- `fs/tmp.c`
- `fs/proc.c`
- `fs/pty.c`

Linux `getdents64` exposes a `d_type` byte for each directory entry. The ARM64
port previously returned `DT_UNKNOWN` for every entry even when the backing
filesystem knew the type. That is legal but incomplete, and it breaks runtimes
that use `d_type` as a fast path for recursive directory walks. Bun's
`fs.cpSync(..., { recursive: true })` hit this during PiClaw workspace bootstrap:
it treated subdirectories under `skel/.pi/skills` as ordinary copy targets and
failed with:

```text
ENOTSUP: operation not supported on socket, copyfile
```

Directory reads now propagate or infer Linux `DT_*` values:

- realfs uses host `dirent.d_type`;
- tmpfs/proc infer from inode/proc modes;
- devpts reports pty entries as `DT_CHR`;
- fakefs inherits the realfs type while substituting its fake inode number.

Validation: a minimal Bun recursive `fs.cpSync` directory tree copy succeeds,
PiClaw no longer logs the bootstrap `ENOTSUP ... copyfile` warning, and staged
runtime coverage remains 20/20.

## Current ABI shape

The practical host-facing ABI is now:

### Signal/crash ABI

- `platform/host_context_aarch64.h`
- ARM64 `siginfo_t` layout and thread-directed signal codes in `kernel/signal.*`
- ARM64 syscall-table signal entries in `kernel/arch/arm64/calls.c`

### Platform statistics ABI

- `platform/linux.c`
- `platform/darwin.c`
- `platform/platform.h`

### Fakefs/path ABI

- localized helpers in `fs/fake.c`

### JIT fault/retry ABI

- `fiber_frame::jit_saved_pc`
- `gadget_set_jit_saved_pc`
- host signal recovery in `main.c`
- TLB/cross-page fault exits in ARM64 memory gadgets

### Runtime compatibility shims

- ARM64 exec-time environment injection in `kernel/exec.c`, currently including
  `GODEBUG=asyncpreemptoff=1`, `GOMAXPROCS=2`, `JSC_numberOfGCMarkers=1`, and `JSC_useConcurrentGC=0`

This is not yet a full `host_*` layer, but it is a clear first split:

- register/context access is no longer open-coded per host
- fakefs no longer assumes Apple-only fd/path APIs
- ARM64 JIT crash recovery no longer assumes block-start retry is safe for every memory fault
- runtime-specific compatibility shims are documented where they cross signal/threading ABI boundaries

---

## Recommended next cleanup

If we want the Linux/macOS/iOS split to stay clean as the project grows, the next
small refactor should be:

- move fd-path lookup and stat-timestamp helpers out of `fs/fake.c`
- into a narrow host API, e.g. `platform/host_fs_abi.h`

That would make the host seams explicit in the same way the signal/ucontext seam now is.
