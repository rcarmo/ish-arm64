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
