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

## Current ABI shape

The practical host-facing ABI is now:

### Signal/crash ABI

- `platform/host_context_aarch64.h`

### Platform statistics ABI

- `platform/linux.c`
- `platform/darwin.c`
- `platform/platform.h`

### Fakefs/path ABI

- localized helpers in `fs/fake.c`

This is not yet a full `host_*` layer, but it is a clear first split:

- register/context access is no longer open-coded per host
- fakefs no longer assumes Apple-only fd/path APIs

---

## Recommended next cleanup

If we want the Linux/macOS/iOS split to stay clean as the project grows, the next
small refactor should be:

- move fd-path lookup and stat-timestamp helpers out of `fs/fake.c`
- into a narrow host API, e.g. `platform/host_fs_abi.h`

That would make the host seams explicit in the same way the signal/ucontext seam now is.
