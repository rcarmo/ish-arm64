# Benchmarks Game Go smoke report

- Timestamp: 2026-05-03T05:55:58+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 900s
- guest workdir: /tmp/benchmarksgame-go-smoke
- Result: 10 / 10 passing

## Selected Go source variants

| Benchmark | Program page | Skipped self-contained alternatives |
|---|---|---|
| binarytrees | binarytrees-go-2.html | — |
| fannkuchredux | fannkuchredux-go-3.html | — |
| fasta | fasta-go-2.html | — |
| knucleotide | knucleotide-go-7.html | — |
| mandelbrot | mandelbrot-go-4.html | — |
| nbody | nbody-go-3.html | — |
| pidigits | pidigits-go-6.html | pidigits-go-4.html,pidigits-go-1.html,pidigits-go-3.html,pidigits-go-2.html |
| regexredux | regexredux-go-3.html | regexredux-go-5.html,regexredux-go-4.html |
| revcomp | revcomp-go-6.html | — |
| spectralnorm | spectralnorm-go-4.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 0.12 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 0.18 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 0.18 |
| knucleotide | PASS | 136 | 15 | 1140896396:136 | 0.15 |
| mandelbrot | PASS | 1211 | 2 | 1840259308:1211 | 0.12 |
| nbody | PASS | 26 | 2 | 980964627:26 | 0.11 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 0.10 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 0.26 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 0.15 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 0.20 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:0.12
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.18
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:0.18
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:0.15
__BG_RESULT:knucleotide:PASS:136:15:1140896396:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:0.12
__BG_RESULT:mandelbrot:PASS:1211:2:1840259308:1211
__BG_BEGIN:nbody
__BG_TIME:nbody:0.11
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:0.10
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.26
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.15
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:0.20
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
