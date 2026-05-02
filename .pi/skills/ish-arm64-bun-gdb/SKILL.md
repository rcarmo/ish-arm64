---
name: ish-arm64-bun-gdb
description: Debug Bun allocator/free-list corruption in the ARM64 iSH threaded-code backend with GDB and tmux.
---

# iSH ARM64 Bun allocator GDB workflow

Use this skill when Bun fails inside `/workspace/projects/ish-arm64` with allocator/free-list corruption, especially faults around:

```text
0x4899afc / 0x4899b00
0x48968ec / 0x48968f0
0x4897400..0x4897460
0x4898910
```

## Repository and baseline

```bash
cd /workspace/projects/ish-arm64
git status --short --branch
make build-arm64-linux-all
```

The canonical push target used during this work is:

```bash
git push https://github.com/rcarmo/ish-arm64.git master
```

Local `origin` may still point at `OpenMinis/ish-arm64`, so an `ahead` status is expected.

## Reproducer

Run this in the ARM64 Alpine fakefs:

```bash
timeout 300 ./build-arm64-linux/ish -f alpine-arm64-fakefs /bin/sh -c '
  export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
  rm -rf /tmp/bun-gdb
  mkdir -p /tmp/bun-gdb/localdep
  cd /tmp/bun-gdb || exit 1
  printf "{\"name\":\"x\",\"private\":true,\"dependencies\":{\"localdep\":\"file:./localdep\"}}\n" > package.json
  printf "{\"name\":\"localdep\",\"version\":\"1.0.0\",\"exports\":\"./index.js\"}\n" > localdep/package.json
  printf "export const marker=1;\n" > localdep/index.js
  bun install
  echo RC:$?
'
```

Typical bad symptom:

```text
page fault on 0x... at 0x4899afc (read)
page fault on 0x... at 0x4899b00 (write)
```

## Start GDB in tmux

Use `tmux` so the session survives long runs and can be interrupted/inspected:

```bash
cd /workspace/projects/ish-arm64
tmux new-session -d -s bun-gdb -c /workspace/projects/ish-arm64 \
  'gdb -q ./build-arm64-linux-debug/ish'
tmux attach -t bun-gdb
```

Inside GDB, always disable the signals used by the emulator before running:

```gdb
set pagination off
set confirm off
set print thread-events off
set breakpoint pending on
handle SIGPIPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
handle SIGUSR2 nostop noprint pass
```

Run the reproducer as one GDB `run` command. If quoting becomes painful, use `tmux send-keys -l` with a prepared `/workspace/tmp/gdb-runline.txt`.

## Critical finding to preserve

The bad `meta+8` freelist head is usually **not first written by the metadata slow-pop store**. GDB showed the corruption originates earlier when Bun's freelist builder writes a bogus `next` pointer into an object header.

Captured bad slow-pop metadata store:

```text
== BAD slow-pop store about to write meta+8 ==
hostpc=0xaaaaaab0ae94
x22(param)=0x81308
value/x23=0x23cdaa8090300
x0(obj)=0x23aa0080100
x19(meta)=0x23a9f032800
x20(size)=0x100
x30=0x4896a14

meta+8 before store: 0x0000023aa0080100
object[0]:           0x00023cdaa8090300  <-- bad next pointer already present
```

So slow-pop is promoting a bad object header into metadata; it is not necessarily the first corrupting writer.

## Freelist builder path

The bad object header write was caught at Bun code around:

```asm
4897400:
 4897408: ldrh w11, [x0, #18]
 489740c: ldr  x10, [x0, #48]
 4897410: add  x9, x2, x11
 4897414: mul  x12, x1, x11
 ...
 4897430: madd x11, x1, x11, x1
 4897434: add  x10, x10, x11
 4897438: mov  x11, x8
 4897440: str  x10, [x11]      ; writes freelist next pointer
 4897444: add  x11, x11, x1
 4897448: add  x10, x10, x1
```

GDB caught a bad store before slow-pop:

```text
== high 64-bit store (not slow-pop meta store) ==
target/x7 = 0x4aabf3d0240
value/x23 = 0x1c4b2761d0300
param/x22 = 0xb0a
x30       = 0x4898910
```

This corresponds to the `str x10, [x11]` loop storing a bogus `next` pointer.

## Earlier bad input at MADD

The key earlier breakpoint is `madd_store`. It showed `x11` is already stale before `madd x11, x1, x11, x1`:

```text
== MADD produced high x11 ==
result/x3 = 0x1333ed7400060
rn/x15    = 0x60
rm/x16    = 0x333523e0000   <-- stale x11 input, should be small count
ra/x17    = 0x60
rd/x9     = 0xb
param/x8  = 0x210b010b

x0  = 0x33351432350
x1  = 0x60
x2  = 0x2a
x8  = 0x333523e0000
x9  = 0x333523e0f60
x10 = 0x333523e0060
x11 = 0x333523e0000   <-- wrong/stale
x19 = 0x33351432350
x20 = 0x2a
x30 = 0x4898910
```

Expected source at this point is the 16-bit count loaded by:

```asm
4897408: ldrh w11, [x0, #18]
```

Follow-up GDB showed `gadget_load16_imm_fast` itself can be fragile on TLB read misses if it keeps the precomputed `CPU_x0` pointer in caller-saved `x11` across `read_prep`: the miss path calls C and can clobber `x11`. Recompute `add x11, _cpu, #CPU_x0` after `read_prep` in fast fused load gadgets before writing the destination register. This is a real correctness fix but was **not sufficient** to make Bun pass.

After that fix, `ldrh w11, [x0,#18]` was observed setting guest `x11=0` for the bad size class, then `x11` later became the loop pointer (`mov x11, x8` inside the freelist-fill loop). A hardware watchpoint on the guest `x11` slot showed the corrupt sequence precisely:

```text
0      -> 0x60              madd x11, x1, x11, x1   (first correct entry)
0x60   -> heap_base         mov  x11, x8
heap_base -> huge_bad_next  madd x11, x1, x11, x1   (bad re-entry/restart)
huge_bad_next -> heap_base  mov  x11, x8
heap_base += 0x60 ...       loop increments
```

The fix was to make ARM64 JIT memory-fault retry precise without changing normal successful block execution:

- Add `fiber_frame::jit_saved_pc` and a `gadget_set_jit_saved_pc` marker emitted before each ARM64 load/store instruction.
- On async host SIGSEGV/SIGBUS recovery, restore `cpu->pc` from `frame->jit_saved_pc` instead of the block-start TLS fallback.
- On TLB miss/cross-page memory fault paths that return `INT_GPF`, also restore `cpu->pc` from `LOCAL_jit_saved_pc` before `fiber_exit`.
- Avoid the retry path deadlocking on writer-preferred rwlocks by using try-read reacquire after failed JIT lock upgrades and by not blocking on jetsam cleanup while still holding `mem->lock` for reading.

This makes the fault at `4897440: str x10, [x11]` retry at `4897440`, preserving the already-computed `x10/x11`, instead of restarting at `4897430` and re-running `madd` with `x11` holding the loop pointer. Validation: `make build-arm64-linux-all` and 50 consecutive Bun local `file:` install repro runs passed (`RC:0`).

## Useful GDB breakpoints

### Catch bad slow-pop promotion into metadata

This breaks after `store64_imm_fast` has loaded the value from guest `x8` but before it stores to `[x19,#8]` for instruction `str x8, [x19,#8]` (`param == 0x81308`):

```gdb
break *gadget_store64_imm_fast+20 if $x22 == 0x81308 && $x23 > 0xffffffffffff
commands
silent
printf "\n== BAD slow-pop store about to write meta+8 ==\n"
printf "hostpc=%#lx x22(param)=%#lx value/x23=%#lx codeptr/x28=%#lx cpu=%#lx tlb=%#lx\n", $pc, $x22, $x23, $x28, $x1, $x2
printf "guest regs: x0=%#llx x8=%#llx x19=%#llx x20=%#llx x30=%#llx cycle=%#llx sp=%#llx\n", *(unsigned long long*)($x1+0x10), *(unsigned long long*)($x1+0x50), *(unsigned long long*)($x1+0xa8), *(unsigned long long*)($x1+0xb0), *(unsigned long long*)($x1+0x100), *(unsigned long long*)($x1+0x8), *(unsigned long long*)($x1+0x108)
set $meta = *(unsigned long long*)($x1+0xa8)
set $obj = *(unsigned long long*)($x1+0x10)
printf "meta=%#llx obj=%#llx\n", $meta, $obj
p/x mem_ptr(current->mem, $meta, 0)
p/x mem_ptr(current->mem, $obj, 0)
x/6gx mem_ptr(current->mem, $meta, 0)
x/6gx mem_ptr(current->mem, $obj, 0)
bt 8
end
```

### Catch object-header stores of high pointer-looking values

This catches non-slow-pop 64-bit stores after address calculation but before write prep:

```gdb
break *gadget_store64_imm_fast+44 if $x23 > 0xffffffffffff && $x22 != 0x81308 && ($x7 & 0xf) == 0 && $x7 > 0x100000000 && ($x23 & 0xfff) == 0x300
commands
silent
printf "\n== high 64-bit store (not slow-pop meta store) ==\n"
printf "hostpc=%#lx target/x7=%#lx value/x23=%#lx param/x22=%#lx codeptr/x28=%#lx cpu=%#lx\n", $pc, $x7, $x23, $x22, $x28, $x1
printf "guest regs: x0=%#llx x1=%#llx x2=%#llx x3=%#llx x8=%#llx x9=%#llx x10=%#llx x19=%#llx x20=%#llx x21=%#llx x30=%#llx cycle=%#llx sp=%#llx\n", *(unsigned long long*)($x1+0x10), *(unsigned long long*)($x1+0x18), *(unsigned long long*)($x1+0x20), *(unsigned long long*)($x1+0x28), *(unsigned long long*)($x1+0x50), *(unsigned long long*)($x1+0x58), *(unsigned long long*)($x1+0x60), *(unsigned long long*)($x1+0xa8), *(unsigned long long*)($x1+0xb0), *(unsigned long long*)($x1+0xb8), *(unsigned long long*)($x1+0x100), *(unsigned long long*)($x1+0x8), *(unsigned long long*)($x1+0x108)
x/4gx mem_ptr(current->mem, $x7, 0)
bt 6
end
```

### Catch the stale `x11` at MADD

```gdb
break madd_store if $x9 == 11 && $x3 > 0xffffffffffff && $x15 <= 0x1000 && $x17 <= 0x1000
commands
silent
printf "\n== MADD produced high x11 ==\n"
printf "hostpc=%#lx result/x3=%#lx rn/x15=%#lx rm/x16=%#lx ra/x17=%#lx rd/x9=%#lx param/x8=%#lx codeptr/x28=%#lx cpu=%#lx\n", $pc, $x3, $x15, $x16, $x17, $x9, $x8, $x28, $x1
printf "guest regs: x0=%#llx x1=%#llx x2=%#llx x8=%#llx x9=%#llx x10=%#llx x11=%#llx x19=%#llx x20=%#llx x30=%#llx cycle=%#llx sp=%#llx\n", *(unsigned long long*)($x1+0x10), *(unsigned long long*)($x1+0x18), *(unsigned long long*)($x1+0x20), *(unsigned long long*)($x1+0x50), *(unsigned long long*)($x1+0x58), *(unsigned long long*)($x1+0x60), *(unsigned long long*)($x1+0x68), *(unsigned long long*)($x1+0xa8), *(unsigned long long*)($x1+0xb0), *(unsigned long long*)($x1+0x100), *(unsigned long long*)($x1+0x8), *(unsigned long long*)($x1+0x108)
bt 6
end
```

## Things already ruled out

- Guest ASLR/address randomization: guest personality is `ADDR_NO_RANDOMIZE_` and repeated `/proc/self/maps` for simple shells are deterministic.
- Host ASLR: `setarch aarch64 -R` does not remove the Bun failure.
- Deterministic guest entropy: forcing deterministic `getrandom` changes repeatability of addresses but not the failure.
- Block chaining: temporarily defining `DISABLE_BLOCK_CHAINING` still reproduces the allocator corruption.
- Slow-pop metadata store as first writer: GDB showed the object header is already bad before slow-pop stores it to `meta+8`.

## Next debugging target

Focus on the instruction window:

```asm
4897408: ldrh w11, [x0, #18]
4897430: madd x11, x1, x11, x1
```

`gadget_load16_imm_fast` was audited and one real miss-path clobber bug was found/fixed: fast fused loads must not assume caller-saved `x11` survives `read_prep` if the miss path calls C.

The concrete remaining question is now:

> Why can execution enter `4897430` with guest `x11` already holding the freelist loop pointer from `4897438: mov x11, x8`?

Use GDB watchpoints on:

- guest CPU register slot for `x11`: `cpu + CPU_x0 + 11*8`, offset `0x68`
- guest CPU `pc`: offset `0x110`

A useful condition is `pc == 0x4897430 && x11 > 0xffffffffffff` after stopping on the Bun thread. This should identify the control-flow writer/re-entry path that restarts the block with stale loop state.
