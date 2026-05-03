# Benchmarks Game PHP smoke report

- Timestamp: 2026-05-03T16:16:31+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-php-smoke
- Result: 10 / 10 passing

## Selected PHP source variants

| Benchmark | Program page | Skipped external-dependency alternatives |
|---|---|---|
| binarytrees | binarytrees-php-7.html | — |
| fannkuchredux | fannkuchredux-php-4.html | — |
| fasta | fasta-php-3.html | — |
| knucleotide | knucleotide-php-4.html | — |
| mandelbrot | mandelbrot-php-3.html | — |
| nbody | nbody-php-3.html | — |
| pidigits | pidigits-php-5.html | — |
| regexredux | regexredux-php-1.html | — |
| revcomp | revcomp-php-3.html | — |
| spectralnorm | spectralnorm-php-1.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 145 | 5 | 2182227464:145 | 0.16 |
| fannkuchredux | PASS | 25 | 3 | 972231165:25 | 0.22 |
| fasta | PASS | 10246 | 172 | 2878930527:10246 | 0.13 |
| knucleotide | PASS | 3351 | 151 | 25393366:3351 | 0.12 |
| mandelbrot | PASS | 2191 | 117 | 3171205362:2191 | 0.11 |
| nbody | PASS | 2874 | 101 | 3521494491:2874 | 0.09 |
| pidigits | PASS | 152 | 11 | 952697893:152 | 0.11 |
| regexredux | PASS | 264 | 14 | 3231244428:264 | 0.15 |
| revcomp | PASS | 10175 | 169 | 2729852449:10175 | 0.11 |
| spectralnorm | PASS | 3307 | 161 | 3342231173:3307 | 0.09 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:0.16
__BG_RESULT:binarytrees:PASS:145:5:2182227464:145
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.22
__BG_RESULT:fannkuchredux:PASS:25:3:972231165:25
__BG_BEGIN:fasta
__BG_TIME:fasta:0.13
__BG_RESULT:fasta:PASS:10246:172:2878930527:10246
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:0.12
__BG_RESULT:knucleotide:PASS:3351:151:25393366:3351
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:0.11
__BG_RESULT:mandelbrot:PASS:2191:117:3171205362:2191
__BG_BEGIN:nbody
__BG_TIME:nbody:0.09
__BG_RESULT:nbody:PASS:2874:101:3521494491:2874
__BG_BEGIN:pidigits
__BG_TIME:pidigits:0.11
__BG_RESULT:pidigits:PASS:152:11:952697893:152
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.15
__BG_RESULT:regexredux:PASS:264:14:3231244428:264
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.11
__BG_RESULT:revcomp:PASS:10175:169:2729852449:10175
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:0.09
__BG_RESULT:spectralnorm:PASS:3307:161:3342231173:3307
__BG_ALL_DONE

```
