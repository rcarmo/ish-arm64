# ARM64 iSH workload smoke tests

Updated: 2026-05-03

## Purpose

This file is the single index for non-trivial workloads we use to harden the ARM64 iSH Linux-host fakefs. The goal is to move beyond tiny instruction reproducers and run real language runtimes, package managers, compilers, filesystem walkers, network servers, and SIMD-heavy applications that resemble what users actually do inside iSH.

A workload belongs here when it exercises at least one of these boundaries:

- Linux syscall fidelity: `mmap`, `mprotect`, `clone`, futexes, signals, timers, vector I/O, directory walking, sockets, file metadata, and `/proc` probes.
- ARM64 instruction coverage: baseline integer/FP, atomics, AdvSIMD/NEON, FP conversion, and guest fault retry correctness.
- Runtime stress: GC, JIT/AOT assumptions, thread scheduling, high-address mappings, memory reservation, and package manager filesystem behavior.
- Reproducibility: the workload can be rerun from a command line in the Linux-host harness and can produce a concise pass/fail log.

## Current workload groups

| Workload | Current status | Why it was chosen | Latest useful log/report |
|---|---:|---|---|
| Staged runtime coverage | Passing, 20/20 | Fast regression gate for shell, `apk`, tmp I/O, C, Go, Bun, Node/npm. Catches broad syscall/runtime regressions before heavier probes. | `/workspace/tmp/ish-arm64-runtime-coverage-20260502-223437.md` |
| Bun + PiClaw bootstrap/server | Passing for install/start/web listen | Exercises modern JS runtime behavior: high `mmap` reservations, JSC GC signaling/timers, recursive package/workspace copies, sockets, HTTP serving, and PiClaw's startup probes. | `/workspace/tmp/piclaw-yolo-run-enotsup-fixed.log` and exposed server logs |
| `rcarmo/go-gte` | Model conversion, `go test ./...`, and `make run-go` passing; `make go-build` still has upstream missing `cmd/test_gte` | Exercises Go toolchain, Python wheels, safetensors/numpy model conversion, 128 MB binary model I/O, FP16→FP32 AdvSIMD conversion, NEON math kernels, and Go runtime scheduling. | `docs/GO_GTE_PROGRESS.md` |
| Benchmarks Game suite | Go, Python, Node.js, Perl, and Ruby rows passing 10/10; source/language feasibility mapped | Broad cross-language benchmark corpus covering allocation, recursion, numeric FP, regex/text throughput, big integers, stdout/stdin streams, native compilers, managed runtimes, and package availability. | [BENCHMARKSGAME_MATRIX.md](BENCHMARKSGAME_MATRIX.md), [BENCHMARKSGAME_GO_SMOKE.md](BENCHMARKSGAME_GO_SMOKE.md), [BENCHMARKSGAME_PYTHON_SMOKE.md](BENCHMARKSGAME_PYTHON_SMOKE.md), [BENCHMARKSGAME_NODE_SMOKE.md](BENCHMARKSGAME_NODE_SMOKE.md), [BENCHMARKSGAME_PERL_SMOKE.md](BENCHMARKSGAME_PERL_SMOKE.md), [BENCHMARKSGAME_RUBY_SMOKE.md](BENCHMARKSGAME_RUBY_SMOKE.md) |

## Staged runtime coverage

Command:

```sh
make test-arm64-runtime-coverage REPORT_DIR=/workspace/tmp TIMEOUT_S=120 INSTALL_TIMEOUT_S=300
```

Latest result:

```text
20 / 20 passing
report: /workspace/tmp/ish-arm64-runtime-coverage-20260502-223437.md
```

Why it matters:

- Establishes the guest can boot, run shell commands, update package indexes, and do basic file I/O.
- Confirms C compile/execute and Go compile/run/build/test paths.
- Keeps Bun and Node/npm smoke coverage in the standard gate so JS runtime regressions are caught quickly.

## Bun + PiClaw workload

Validated result:

```text
NO_ENOTSUP
Web UI listening ... port 18093
READY
```

Bugs exposed and fixed:

- Precise ARM64 memory-fault retry for Bun/JSC allocator correctness.
- Conservative JSC GC/timer shims for guest signal-delivery behavior.
- `REV16` SIMD support for Bun startup paths.
- `getdents64` `d_type` reporting so Bun recursive `fs.cpSync()` no longer attempts `copyfile` on directories during PiClaw bootstrap.

Why it matters:

- PiClaw is a real workspace application, not a synthetic microbenchmark.
- It stresses recursive filesystem copies, package-manager-installed trees, HTTP sockets, runtime worker startup, background indexing, SQLite, and `/proc`/CPU information fallbacks.

## go-gte workload

Detailed progress: [`docs/GO_GTE_PROGRESS.md`](GO_GTE_PROGRESS.md).

Validated in guest:

```sh
cd /tmp/go-gte
python3 convert_model.py models/gte-small gte-small.gtemodel
make run-go
```

Current key result:

```text
Model saved to gte-small.gtemodel
File size: 127.51 MB
CONVERT_RC:0

Model loaded in 5.64 s
Embedding dimension: 384
Max sequence length: 512
```

Bug exposed and fixed:

- Missing AdvSIMD `FCVTL`/`FCVTL2` support. `numpy`/safetensors conversion trapped on `fcvtl v30.4s, v31.4h`; the emulator now handles H→S and S→D widening conversions.

Patched upstream status:

- go-gte `d908cdb` fixes the direct ARM64 `SgemmNT` test failures by completing the `F0`→`F20` rename. `GTE_MODEL_PATH=gte-small.gtemodel go test -count=1 ./...` now passes inside iSH.
- `make run-go` passes.
- `make go-build` still references missing `./cmd/test_gte`; this is a repository Makefile issue rather than an iSH failure.

## Benchmarks Game as the next test case

Source site:

- <https://benchmarksgame-team.pages.debian.net/benchmarksgame/>
- Source repository: <https://salsa.debian.org/benchmarksgame-team/benchmarksgame>

The current site advertises 10 active benchmark families and 26 language/runtime labels through the performance pages. The generated full matrix is in [BENCHMARKSGAME_MATRIX.md](BENCHMARKSGAME_MATRIX.md). Execution rows passing so far: Go ([BENCHMARKSGAME_GO_SMOKE.md](BENCHMARKSGAME_GO_SMOKE.md)), Python ([BENCHMARKSGAME_PYTHON_SMOKE.md](BENCHMARKSGAME_PYTHON_SMOKE.md)), Node.js ([BENCHMARKSGAME_NODE_SMOKE.md](BENCHMARKSGAME_NODE_SMOKE.md)), Perl ([BENCHMARKSGAME_PERL_SMOKE.md](BENCHMARKSGAME_PERL_SMOKE.md)), and Ruby ([BENCHMARKSGAME_RUBY_SMOKE.md](BENCHMARKSGAME_RUBY_SMOKE.md)) across all 10 benchmark families:

| Benchmark | Why it exercises iSH |
|---|---|
| `binarytrees` | Allocation churn, recursion, GC, memory pressure, thread/runtime scheduling in some languages. |
| `fannkuchredux` | Integer-heavy loops, array mutation, native-code tight loops, bounds-check behavior. |
| `fasta` | Large stdout streams, string/byte generation, buffered I/O. |
| `knucleotide` | Hash tables, string slicing, stdin parsing, large text processing. |
| `mandelbrot` | Floating-point numeric loops, output encoding, SIMD/compiler optimization exposure. |
| `nbody` | Floating-point math and long-running numeric loops. |
| `pidigits` | Big integers, arbitrary precision libraries, stdout formatting. |
| `regexredux` | Regex engines, large stdin, text substitution throughput. |
| `revcomp` | Large stdin/stdout, byte transforms, streaming text processing. |
| `spectralnorm` | Floating-point kernels, numerical stability, compiler/runtime math paths. |

### Language/runtime feasibility on Alpine aarch64

Canonical generated matrix: [BENCHMARKSGAME_MATRIX.md](BENCHMARKSGAME_MATRIX.md). Regenerate it with:

```sh
tests/arm64/benchmarksgame/generate-matrix.py
```

Official labels observed in the site pages and first-pass Alpine 3.23 aarch64 package feasibility:

| Label | Guest feasibility | Notes |
|---|---:|---|
| `gcc` | ready | `gcc` package. |
| `gpp` | ready | `g++` package. |
| `gnat` | ready | `gcc-gnat` package is available. |
| `go` | ready | `go` package already validated. |
| `rust` | ready-large | `rust`/`cargo` available; expect large install and compile times. |
| `python3` | ready | Already validated. |
| `node` | ready | `nodejs`/`npm` already validated. |
| `php` | ready | `php84` package available. |
| `perl` | ready | `perl` available. |
| `ruby` | ready | `ruby` available. |
| `lua` | ready | Use `lua5.4`. |
| `ghc` | ready-large | `ghc` available; large install/runtime. |
| `ocaml` | ready-large | `ocaml` available. |
| `sbcl` | ready-large | `sbcl` available. |
| `racket` | ready-large | `racket` available. |
| `csharpaot` | partial/external | `dotnet` packages exist, NativeAOT workload not yet verified. |
| `fsharpcore` | partial/external | `dotnet` packages exist, F# SDK/workload not yet verified. |
| `erlang` | blocked/needs investigation | Alpine v3.23 aarch64 index showed `erlang-ls` but no obvious Erlang runtime package. |
| `chapel` | blocked | No Alpine aarch64 package found. |
| `dartexe` | blocked | No Dart SDK package found; only `dart-sass-js`. |
| `fpascal` | blocked | No Free Pascal package found. |
| `graalvmaot` | blocked/external | No GraalVM AOT package found. OpenJDK can be a JVM smoke substitute, but not the official label. |
| `ifx` | blocked | Intel Fortran unavailable on Alpine/aarch64. |
| `julia` | blocked | No Alpine aarch64 package found. |
| `pharo` | blocked | No obvious Alpine package. |
| `swift` | blocked | No Swift package. |


### First execution row: Go

Command:

```sh
tests/arm64/benchmarksgame/run-go-smoke.sh
```

Latest result:

```text
10 / 10 passing
report: /workspace/tmp/benchmarksgame-go-smoke-20260503-055307.md
```

The Go row intentionally chooses self-contained official Go variants for the first tier. Faster `pidigits` and `regexredux` variants that require cgo/GMP/PCRE are tracked as a separate cgo/toolchain stress pass. During manual probing, the cgo `pidigits` variant exposed `cc: fatal error: failed to get exit status: Interrupted system call` while compiling `runtime/cgo`; this was fixed by treating the internal 1-second `wait4` poll timeout as a timeout, not as a guest `EINTR`. A minimal cgo build and cgo/GMP `pidigits` now compile and run.

### Second execution row: Python

Command:

```sh
tests/arm64/benchmarksgame/run-python-smoke.sh
```

Latest result:

```text
10 / 10 passing
report: /workspace/tmp/benchmarksgame-python-smoke-20260503-072937.md
```

Issue found and fixed: Python `multiprocessing.SemLock` fails with `FileNotFoundError` when `/dev/shm` is absent from the fakefs root. iSH startup now pre-creates `/dev/shm` with mode `1777`, and the Python row passes without creating it in the harness. Many Linux runtimes assume `/dev/shm` exists even when it is just a regular tmp-capable directory.


### Third execution row: Node.js

Command:

```sh
tests/arm64/benchmarksgame/run-node-smoke.sh
```

Latest result:

```text
10 / 10 passing
report: /workspace/tmp/benchmarksgame-node-smoke-20260503-073225.md
```

The first Node.js row intentionally avoids `worker_threads` and external modules such as `mpzjs`, keeping this lane single-process and dependency-free. The skipped worker-thread variants should become a separate scheduler/futex stress lane.

### Fourth execution row: Perl

Command:

```sh
tests/arm64/benchmarksgame/run-perl-smoke.sh
```

Latest result:

```text
10 / 10 passing
report: /workspace/tmp/benchmarksgame-perl-smoke-20260503-080129.md
```

The first Perl row adapts `pidigits` to use stdlib `Math::BigInt` because Alpine does not package `Math::BigInt::GMP`. The GMP variant remains useful as a separate dependency/native-extension stress lane.

### Fifth execution row: Ruby

Command:

```sh
tests/arm64/benchmarksgame/run-ruby-smoke.sh
```

Latest result:

```text
10 / 10 passing
report: /workspace/tmp/benchmarksgame-ruby-smoke-20260503-141652.md
```

The Ruby row now includes Thread/fork-heavy variants. Manual probing of `regexredux-ruby-3` found a false positive in the poll safety valve while other guest threads were still doing CPU work. iSH now only fires that safety valve when all threads are blocking; the Thread/fork-heavy Ruby row now passes.

### Proposed harness shape

The next repeatable test should be tiered instead of pretending all 26 official labels are equally installable on Alpine aarch64:

1. **Discovery tier** — scrape the active performance pages, list benchmark/language/source variants, and record unavailable labels explicitly.
2. **Core tier** — run one representative implementation per benchmark for already-validated runtimes: `gcc`, `gpp`, `go`, `python3`, `node`, `php`, `perl`, `ruby`, `lua`.
3. **Compiler tier** — add large but packaged compilers/runtimes: `rust`, `ghc`, `ocaml`, `sbcl`, `racket`, `gnat`.
4. **External tier** — only after explicit setup: .NET NativeAOT/F#, GraalVM, and other non-Alpine toolchains if we decide to vendor or install them manually.
5. **Unsupported ledger** — keep blocked official labels in the report so "all languages" means "all official labels accounted for", not silently skipped.

The pass/fail artifact should include:

- benchmark name;
- official language label;
- source URL or page;
- compiler/interpreter command;
- input size used for smoke mode;
- exit code;
- elapsed time;
- first/last output checksum or byte count;
- whether the failure is setup/toolchain, iSH syscall/instruction, or benchmark-source related.

### First commands used for feasibility mapping

```sh
curl -fsSL https://benchmarksgame-team.pages.debian.net/benchmarksgame/ -o index.html
git clone --depth 1 https://salsa.debian.org/benchmarksgame-team/benchmarksgame.git /workspace/tmp/benchmarksgame-src
```

The site pages were scraped for `../program/...` links; the package feasibility table was checked against Alpine 3.23 aarch64 `APKINDEX` files for `main` and `community`.
