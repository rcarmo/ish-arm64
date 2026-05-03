# Benchmarks Game Ruby smoke report

- Timestamp: 2026-05-03T14:17:27+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-ruby-smoke
- Result: 10 / 10 passing

## Selected Ruby source variants

| Benchmark | Program page | Skipped alternatives |
|---|---|---|
| binarytrees | binarytrees-ruby-5.html | — |
| fannkuchredux | fannkuchredux-ruby-2.html | — |
| fasta | fasta-ruby-6.html | — |
| knucleotide | knucleotide-ruby-1.html | — |
| mandelbrot | mandelbrot-ruby-5.html | — |
| nbody | nbody-ruby-3.html | — |
| pidigits | pidigits-ruby-1.html | — |
| regexredux | regexredux-ruby-3.html | — |
| revcomp | revcomp-ruby-4.html | — |
| spectralnorm | spectralnorm-ruby-5.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 1.91 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 2.07 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 1.76 |
| knucleotide | PASS | 136 | 15 | 2155388821:136 | 2.56 |
| mandelbrot | PASS | 1311 | 2 | 2518315031:1311 | 2.94 |
| nbody | PASS | 26 | 2 | 980964627:26 | 1.88 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 1.91 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 1.99 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 1.74 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 10.27 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:1.91
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:2.07
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:1.76
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:2.56
__BG_RESULT:knucleotide:PASS:136:15:2155388821:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:2.94
__BG_RESULT:mandelbrot:PASS:1311:2:2518315031:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:1.88
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:1.91
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:1.99
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:1.74
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:10.27
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
