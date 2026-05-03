# Benchmarks Game Lua smoke report

- Timestamp: 2026-05-03T16:16:50+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-lua-smoke
- Result: 10 / 10 passing

## Selected Lua source variants

| Benchmark | Program page | Skipped external-dependency alternatives |
|---|---|---|
| binarytrees | binarytrees-lua-4.html | — |
| fannkuchredux | fannkuchredux-lua-1.html | — |
| fasta | fasta-lua-2.html | — |
| knucleotide | knucleotide-lua-2.html | — |
| mandelbrot | mandelbrot-lua-6.html | — |
| nbody | nbody-lua-2.html | — |
| pidigits | pidigits-lua-7.html | pidigits-lua-1.html:require"bn"/require"bn" |
| regexredux | regexredux-lua-1.html | — |
| revcomp | revcomp-lua-2.html | — |
| spectralnorm | spectralnorm-lua-1.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 0.13 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 0.11 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 0.08 |
| knucleotide | PASS | 136 | 15 | 1767775432:136 | 0.28 |
| mandelbrot | PASS | 1311 | 2 | 2518315031:1311 | 0.36 |
| nbody | PASS | 26 | 2 | 980964627:26 | 0.13 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 0.07 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 0.06 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 0.05 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 1.17 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:0.13
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.11
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:0.08
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:0.28
__BG_RESULT:knucleotide:PASS:136:15:1767775432:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:0.36
__BG_RESULT:mandelbrot:PASS:1311:2:2518315031:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:0.13
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:0.07
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.06
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.05
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:1.17
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
