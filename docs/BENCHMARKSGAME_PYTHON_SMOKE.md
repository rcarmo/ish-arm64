# Benchmarks Game Python smoke report

- Timestamp: 2026-05-03T06:38:16+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-python-smoke
- Result: 10 / 10 passing

## Selected Python source variants

| Benchmark | Program page | Skipped external-dependency alternatives |
|---|---|---|
| binarytrees | binarytrees-python3-4.html | — |
| fannkuchredux | fannkuchredux-python3-4.html | — |
| fasta | fasta-python3-5.html | — |
| knucleotide | knucleotide-python3-3.html | — |
| mandelbrot | mandelbrot-python3-7.html | — |
| nbody | nbody-python3-1.html | — |
| pidigits | pidigits-python3-3.html | — |
| regexredux | regexredux-python3-2.html | — |
| revcomp | revcomp-python3-5.html | — |
| spectralnorm | spectralnorm-python3-4.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 1.98 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 1.34 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 2.47 |
| knucleotide | PASS | 244 | 27 | 1302216728:244 | 2.45 |
| mandelbrot | PASS | 1311 | 2 | 1937146726:1311 | 3.24 |
| nbody | PASS | 26 | 2 | 980964627:26 | 0.61 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 1.40 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 1.75 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 1.77 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 8.96 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:1.98
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:1.34
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:2.47
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:2.45
__BG_RESULT:knucleotide:PASS:244:27:1302216728:244
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:3.24
__BG_RESULT:mandelbrot:PASS:1311:2:1937146726:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:0.61
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:1.40
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:1.75
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:1.77
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:8.96
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
