# Benchmarks Game ARM64 iSH test case

Status: planned next workload gate.

Primary design document: [`../../../docs/ARM64_WORKLOAD_SMOKE_TESTS.md`](../../../docs/ARM64_WORKLOAD_SMOKE_TESTS.md).

This directory is reserved for the repeatable harness that will turn the Benchmarks Game corpus into an ARM64 iSH smoke test. The intended shape is:

1. discover active benchmark/language/source variants from the official performance pages;
2. install or verify the selected Alpine aarch64 toolchains;
3. run a smoke-sized input for every feasible benchmark/language pair;
4. record unsupported official language labels explicitly instead of silently skipping them;
5. classify failures as toolchain/setup, benchmark-source, or iSH syscall/instruction/runtime bugs.

The first target tier should cover one representative implementation per active benchmark for the already-validated runtimes: `gcc`, `gpp`, `go`, `python3`, `node`, `php`, `perl`, `ruby`, and `lua`.

## Discovery matrix

Generate the full official-language matrix with:

```sh
tests/arm64/benchmarksgame/generate-matrix.py
```

The output is committed at `docs/BENCHMARKSGAME_MATRIX.md` so changes in the upstream Benchmarks Game site are visible in diffs.

## Go execution row

Run the first actual benchmark row with:

```sh
tests/arm64/benchmarksgame/run-go-smoke.sh
```

This fetches official Go source variants from the public Benchmarks Game pages, prefers self-contained variants for the first tier, pushes them into the guest, builds them with guest `go`, and records a Markdown report. Latest validated result: 10/10 passing.

## Python execution row

Run the Python benchmark row with:

```sh
tests/arm64/benchmarksgame/run-python-smoke.sh
```

Latest validated result: 10/10 passing. The row verifies iSH startup pre-creates `/dev/shm` because Python multiprocessing semaphores require it on musl-based Alpine.

## Node.js execution row

Run the Node.js benchmark row with:

```sh
tests/arm64/benchmarksgame/run-node-smoke.sh
```

Latest validated result: 10/10 passing. The first row avoids `worker_threads` and external modules so we can add those as separate stress lanes.

## Perl execution row

Run the Perl benchmark row with:

```sh
tests/arm64/benchmarksgame/run-perl-smoke.sh
```

Latest validated result: 10/10 passing. `pidigits` is adapted to stdlib `Math::BigInt` because Alpine does not package `Math::BigInt::GMP`.

## Ruby execution row

Run the Ruby benchmark row with:

```sh
tests/arm64/benchmarksgame/run-ruby-smoke.sh
```

Latest validated result: 10/10 passing. This row includes Thread/fork variants after fixing a poll safety-valve false positive found by `regexredux-ruby-3`.
