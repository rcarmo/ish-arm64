# Benchmarks Game ARM64 iSH success matrix

Generated: 2026-05-03T16:20:49+00:00

This is the discovery matrix for the next ARM64 iSH workload gate. It accounts for every official language/runtime label observed on the current Benchmarks Game performance pages and classifies whether each label is runnable with Alpine aarch64 packages, large-but-feasible, external/partial, or blocked.

Legend:

- `R` — source variant exists and the language is in the first runnable Alpine aarch64 tier.
- `L` — source variant exists and the language has an Alpine package but is large/expensive; run after the core tier.
- `P` — source variant exists but needs external/non-default setup before it can run.
- `X` — source variant exists but no practical Alpine aarch64 toolchain is currently identified.
- `?` — source variant exists but package/toolchain discovery needs investigation.
- `—` — no program link for that benchmark/language label on the current site.

## Summary

- Benchmarks: 10
- Official language labels observed: 26
- Program links observed: 937
- Unknown labels needing table updates: none

| Feasibility | Languages |
|---|---:|
| ready | 10 |
| ready-large | 5 |
| partial/external | 2 |
| blocked/needs-investigation | 1 |
| blocked/external | 1 |
| blocked | 7 |

## Language success matrix

| Language | Tier | Variants | binarytrees | fannkuchredux | fasta | knucleotide | mandelbrot | nbody | pidigits | regexredux | revcomp | spectralnorm | Toolchain note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| chapel | blocked | 23 | X | X | X | X | X | X | X | X | X | X | no Alpine aarch64 package found |
| csharpaot | partial/external | 54 | P | P | P | P | P | P | P | P | P | P | dotnet packages exist; NativeAOT not verified |
| dartexe | blocked | 43 | X | X | X | X | X | X | X | X | X | X | no Dart SDK package found |
| erlang | blocked/needs-investigation | 21 | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | no obvious Erlang runtime in Alpine 3.23 aarch64 index |
| fpascal | blocked | 23 | X | X | X | — | X | X | X | X | X | X | no Free Pascal package found |
| fsharpcore | partial/external | 35 | P | P | P | P | P | P | P | P | P | P | dotnet packages exist; F# SDK/workload not verified |
| gcc | ready | 56 | R | R | R | R | R | R | R | R | R | R | gcc |
| ghc | ready-large | 38 | L | L | L | L | L | L | L | L | L | L | ghc |
| gnat | ready | 23 | R | R | R | R | R | R | R | R | R | R | gcc-gnat |
| go | ready | 48 | R | R | R | R | R | R | R | R | R | R | go |
| gpp | ready | 61 | R | R | R | R | R | R | R | R | R | R | g++ |
| graalvmaot | blocked/external | 51 | X | X | X | X | X | X | X | X | X | X | no GraalVM AOT package found |
| ifx | blocked | 24 | X | X | X | X | X | X | X | X | X | X | Intel Fortran unavailable on Alpine/aarch64 |
| julia | blocked | 39 | X | X | X | X | X | X | X | X | X | X | no Alpine aarch64 package found |
| lua | ready | 23 | R | R | R | R | R | R | R | R | R | R | lua5.3/lua5.4; Benchmarks Game pidigits uses LGMP, which requires Lua < 5.4 |
| node | ready | 29 | R | R | R | R | R | R | R | R | R | R | nodejs/npm |
| ocaml | ready-large | 22 | L | L | L | L | L | L | L | L | L | L | ocaml |
| perl | ready | 32 | R | R | R | R | R | R | R | R | R | R | perl |
| pharo | blocked | 15 | X | X | X | X | X | X | X | X | X | X | no obvious Alpine package |
| php | ready | 35 | R | R | R | R | R | R | R | R | R | R | php84 |
| python3 | ready | 41 | R | R | R | R | R | R | R | R | R | R | python3 |
| racket | ready-large | 26 | L | L | L | L | L | L | L | L | L | L | racket |
| ruby | ready | 44 | R | R | R | R | R | R | R | R | R | R | ruby |
| rust | ready-large | 61 | L | L | L | L | L | L | L | L | L | L | rust/cargo |
| sbcl | ready-large | 33 | L | L | L | L | L | L | L | L | L | L | sbcl |
| swift | blocked | 37 | X | X | X | X | X | X | X | X | X | X | no Swift package |

## Benchmark coverage by language count

| Benchmark | Language labels with source variants |
|---|---:|
| binarytrees | 26 |
| fannkuchredux | 26 |
| fasta | 26 |
| knucleotide | 25 |
| mandelbrot | 26 |
| nbody | 26 |
| pidigits | 26 |
| regexredux | 26 |
| revcomp | 26 |
| spectralnorm | 26 |

## Alpine package spot-check

| Package | Repository |
|---|---|
| gcc | main |
| g++ | main |
| gcc-gnat | main |
| go | community |
| rust | main |
| cargo | main |
| python3 | main |
| nodejs | main |
| npm | community |
| php84 | community |
| perl | main |
| ruby | main |
| lua5.3 | main |
| lua5.4 | main |
| ghc | community |
| ocaml | community |
| sbcl | community |
| racket | community |
| mono | community |
| dotnet-host | community |

## Next execution tiers

1. Core tier: `gcc`, `gpp`, `go`, `python3`, `node`, `php`, `perl`, `ruby`, `lua` across all 10 benchmarks with smoke-sized inputs.
2. Compiler tier: add `gnat`, `rust`, `ghc`, `ocaml`, `sbcl`, `racket` once package install cost is acceptable.
3. External tier: attempt .NET/F#, GraalVM, and other non-Alpine labels only after explicit toolchain setup.
4. Blocked ledger: keep `X`/`?` labels in this matrix until they have a real runner or a documented reason they cannot run on Alpine aarch64.

