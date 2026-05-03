# Benchmarks Game Perl smoke report

- Timestamp: 2026-05-03T08:01:45+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-perl-smoke
- Result: 10 / 10 passing

## Selected Perl source variants

| Benchmark | Program page | Skipped/adapted alternatives |
|---|---|---|
| binarytrees | binarytrees-perl-6.html | — |
| fannkuchredux | fannkuchredux-perl-2.html | — |
| fasta | fasta-perl-1.html | — |
| knucleotide | knucleotide-perl-1.html | — |
| mandelbrot | mandelbrot-perl-1.html | — |
| nbody | nbody-perl-2.html | — |
| pidigits | pidigits-perl-1.html | pidigits-perl-1.html:adapted-no-Math::BigInt::GMP |
| regexredux | regexredux-perl-3.html | — |
| revcomp | revcomp-perl-4.html | — |
| spectralnorm | spectralnorm-perl-4.html | — |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 1.38 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 0.70 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 0.27 |
| knucleotide | PASS | 136 | 15 | 2155388821:136 | 1.93 |
| mandelbrot | PASS | 1311 | 2 | 2518315031:1311 | 1.84 |
| nbody | PASS | 26 | 2 | 980964627:26 | 0.37 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 4.83 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 0.60 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 0.07 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 2.51 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:1.38
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.70
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:0.27
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:1.93
__BG_RESULT:knucleotide:PASS:136:15:2155388821:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:1.84
__BG_RESULT:mandelbrot:PASS:1311:2:2518315031:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:0.37
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:4.83
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.60
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.07
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:2.51
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
