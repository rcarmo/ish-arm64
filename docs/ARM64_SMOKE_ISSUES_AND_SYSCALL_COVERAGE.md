# ARM64 smoke issues and syscall coverage appraisal

Updated: 2026-05-04

## Executive status

The current ARM64 Linux-host fakefs is in a good core-runtime state:

- Staged runtime coverage: **21 / 21 passing**.
- Benchmarks Game core tier: **9 language rows × 10 benchmarks = 90 / 90 runs passing**.
- Native compiler rows additionally build inside the guest: **GCC 10 / 10 builds**, **G++ 10 / 10 builds**.
- The rows now include interpreted runtimes, managed runtimes, native compilers, big integers, regex engines, pipes/stdin/stdout, `fork()`, guest pthreads, futex-heavy language runtimes, and SysV shared-memory/message-queue IPC.

## Issues found by smoke workloads

| Area | Symptom | Root cause | Status |
|---|---|---|---|
| Python Benchmarks Game | `multiprocessing.SemLock` failed when `/dev/shm` did not exist. | Fakefs root did not provide the Linux-standard `/dev/shm` directory expected by musl/Python. | **Fixed**: iSH startup pre-creates `/dev/shm` with mode `1777`. |
| Go/cgo Benchmarks Game probe | cgo/GMP `pidigits` compile failed with `failed to get exit status: Interrupted system call`. | iSH's internal bounded `wait4` polling timeout leaked to the guest as `EINTR`. | **Fixed**: internal `_ETIMEDOUT` is retried and no longer returned as guest `EINTR`. |
| Ruby Benchmarks Game | Thread/fork-heavy `regexredux-ruby-3` was killed by `SAFETY-VALVE[poll]`. | Poll safety valve treated one polling thread as whole-process idleness while other guest threads were still doing CPU work. | **Fixed**: poll valve only fires when there are no live children and all threads are blocking. |
| PHP Benchmarks Game | Fast official PHP variants failed in `shmop_*()` and `msg_*()` calls. | ARM64 direct SysV shared memory and message queue syscalls were stubs. | **Fixed**: implemented enough `shmget`/`shmctl`/`shmat`/`shmdt` and `msgget`/`msgctl`/`msgsnd`/`msgrcv` for forked worker result passing. Runtime coverage now includes a C SysV IPC across-`fork()` test. |
| Bun/PiClaw smoke | Bun recursive copy attempted file-copy on directories and hit `ENOTSUP`. | `getdents64` returned `DT_UNKNOWN` instead of directory entry types. | **Fixed**: directory entry `d_type` is now reported. |
| Bun/JSC smoke | Bun allocator/free-list crashes around high heap/cage mappings. | ARM64 fault retry was imprecise for translated load/store blocks; high mmap hints were also mishandled. | **Fixed**: precise memory-fault retry PC and high-address ARM64 mmap handling. |
| Bun/JSC smoke | `bun -e`, timers, and server startup could stall. | JSC parallel/concurrent GC uses signal coordination patterns that exposed iSH scheduling/signal-delivery limits. | **Mitigated correctly for this runtime**: ARM64 guest shim constrains JSC to one marker and disables concurrent GC. |
| go-gte workload | Model conversion trapped on AdvSIMD FP widening conversion. | Missing ARM64 `FCVTL`/`FCVTL2` instruction coverage. | **Fixed**: H→S and S→D widening conversion handlers added. |
| GCC/G++ Benchmarks Game | Several fastest native variants include `immintrin.h`, `x86intrin.h`, SSE, or AVX intrinsics. | Official source is x86-specific, not portable C/C++ and not an ARM64 emulation bug. | **Accounted for, not patched**: rows record these alternatives and select the next official portable source. |
| GCC/G++ Benchmarks Game | Some threaded `revcomp`/`fasta` variants segfault under Alpine/musl. | The source allocates large per-thread VLAs; musl's default pthread stack is much smaller than the Debian/glibc environment used by the benchmark site. | **Accounted for as source/environment limitation**: rows select the next official portable/non-overflowing variant rather than changing benchmark source. |
| G++ Benchmarks Game | `fannkuchredux-gpp-5` does not compile with Alpine's current GCC without a missing include fix. | Source uses `int64_t` without including `<cstdint>`. | **Accounted for as source portability issue**: row selects the next official variant instead of patching source. |
| Node.js Benchmarks Game | First Node row skipped `worker_threads` variants. | At the time this was kept as a scheduler/futex stress lane; after the poll-valve fix, worker creation itself works, but some official worker variants produce no output at smoke-sized inputs. | **No active iSH correctness blocker**; keep as a separate stress/validation lane if we want larger inputs or per-variant expected-output checks. |
| Java/OpenJDK probe | `java -version` fails before Java equivalents can compile/run. | HotSpot aborts early inside AArch64 assembler/runtime setup (`assembler_aarch64.hpp:245` on JDK 17/21; JDK 11 reaches `fieldInfo.hpp:171`). No missing syscall stub is printed; bounded probes show HotSpot then loops while writing its fatal error report. | **Open**: track as a dedicated ARM64 HotSpot correctness lane. Current Java-equivalent Benchmarks Game report is blocked at JVM startup. |
| External dependency alternatives | Perl GMP backend, Node `mpzjs`, Lua `bn`, and similar variants are not always packaged by Alpine. | Missing language-specific third-party packages, not emulator faults. | **Accounted for**: where a packaged/buildable dependency exists we use it (`php84-gmp`, `lua5.3` LGMP via luarocks, PCRE packages); otherwise variants remain external lanes. |

## Current syscall coverage snapshot

Static analysis of `kernel/arch/arm64/calls.c` as of this appraisal:

| Metric | Count | Notes |
|---|---:|---|
| ARM64 syscall table span | 440 slots | Numeric span `0..439`; includes many holes/newer syscalls that are not explicitly named. |
| Explicitly assigned slots | 286 | Includes the `[5 ... 16]` xattr range expanded to 12 slots. |
| Functional `sys_*` implementations | 189 | Real handlers, excluding xattr/success/silent/loud stubs. |
| Compatibility success stub | 1 | `sync` returns success. |
| xattr stub range | 12 | Extended attributes are recognized but not implemented as real storage semantics. |
| Loud `ENOSYS` stubs | 76 | Printed as stub syscall diagnostics when hit. |
| Silent `ENOSYS` stubs | 8 | Modern runtime probes where quiet fallback is expected (`io_uring_*`, `pidfd_*`, `openat2`, `faccessat2`, `memfd_create`). |
| Unassigned slots in span | 154 | Default to `ENOSYS`; mostly gaps between older asm-generic and newer syscall ranges. |

Useful ratios:

- Functional coverage of explicitly assigned ARM64 slots: **189 / 286 = 66.1%**.
- Functional coverage of the full numeric `0..439` span: **189 / 440 = 43.0%**. This denominator overstates practical workload exposure because it includes unassigned holes.
- Functional-or-benign assigned coverage, counting `sync` success and xattr-recognized stubs: **202 / 286 = 70.6%**.

## Coverage strengths

The implemented set is now strong for the workloads currently passing:

- process basics: `clone`, `clone3` fallback behavior, `execve`, `wait4`, `waitid`, `exit`, `exit_group`, tids/pids, groups/users, sessions/process groups;
- memory: `mmap`, high ARM64 mmap hints, `munmap`, `mprotect`, `mremap`, `madvise`, `mincore`, `mlock`, `msync`, lazy `MAP_NORESERVE` reservations;
- synchronization: futex wait/wake/requeue/wake-op, robust lists, nanosleep/timers;
- filesystems: `openat`, `read`/`write`, `readv`/`writev`, `pread`/`pwrite`, `preadv`/`pwritev`, `getdents64`, `statx`, `fstatat`, `copy_file_range`, `sendfile`, `splice`, chmod/chown/link/symlink/rename/unlink/mkdir, `statfs`/`fstatfs`;
- sockets: core TCP/UDP/Unix socket paths, `socketpair`, `accept4`, `sendmsg`/`recvmsg`, `sendmmsg`/`recvmmsg`, fd passing;
- IPC: SysV shared memory and message queues enough for PHP/native smoke; eventfd, epoll, timerfd, inotify;
- runtime probes: `rseq`, quiet fallback stubs for common modern optional probes.

## Known syscall gaps and likely priority

These are not blocking the current smoke set, but they frame the next coverage work:

| Priority | Gap | Why it matters |
|---|---|---|
| High | OpenJDK/HotSpot startup | Java is not on the current Benchmarks Game site, but OpenJDK is a high-value runtime. Current failure occurs before bytecode execution and likely exercises ARM64 code generation, signal/error handling, or memory-layout assumptions not covered by other rows. |
| High if a workload hits it | SysV semaphores: `semget`, `semctl`, `semop`, `semtimedop` | Completes the SysV IPC family; likely needed by older database/IPC-heavy software. |
| High if a workload hits it | `signalfd4` | Modern event loops sometimes prefer signalfd over traditional signal handling. |
| Medium | `memfd_create` real implementation | Currently quiet `ENOSYS`; most runtimes fall back, but some sandbox/JIT/package-manager paths may benefit. |
| Medium | `openat2`, `faccessat2` real implementations | Currently quiet fallback stubs; common on newer glibc but less important on Alpine/musl. |
| Medium | `preadv2`/`pwritev2` | Can usually fall back to `preadv`/`pwritev`; useful for newer native software. |
| Medium | `process_vm_readv`/`process_vm_writev` | Debuggers/profilers and some language tools use these. |
| Medium | POSIX message queues `mq_*` | Less common than SysV IPC in current rows, but a clear IPC gap. |
| Low/currently niche | AIO, `io_uring_*` | Currently quiet fallback works for Node/Bun/npm; true support is a larger subsystem. |
| Low/currently niche | namespaces, keyrings, fanotify, perf, bpf, seccomp, pkeys, NUMA policy | Important for container/security/profiling workloads, not for current language/runtime smoke. |
| Deliberately absent | kernel module, swap, reboot, mount-heavy privileged paths | Not expected to be meaningful inside this fakefs/user-mode emulator environment. |

## Appraisal

For userland development workloads, ARM64 iSH is now past the fragile bring-up phase. The strongest evidence is that the same fakefs can run package installs, C/C++ compilation, Go/Bun/Node/Python/PHP/Perl/Ruby/Lua runtime rows, GMP/PCRE/APR/Boost/TBB-linked native code, `fork()` plus SysV IPC, and the go-gte numerical workload.

The remaining risk is less about the already-exercised syscall/instruction core and more about breadth: optional Linux subsystems that real applications may probe opportunistically. The next best hardening step is to add focused lanes for the known medium/high gaps instead of broadening the Benchmarks Game rows further: SysV semaphores, signalfd, memfd, `preadv2`/`pwritev2`, and `process_vm_*` would give the highest marginal syscall coverage.
