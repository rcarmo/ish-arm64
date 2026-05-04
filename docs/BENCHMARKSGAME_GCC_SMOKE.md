# Benchmarks Game GCC smoke report

- Timestamp: 2026-05-04T06:48:51+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-gcc-smoke
- Build result: 10 / 10 passing
- Result: 10 / 10 passing

## Selected GCC source variants

| Benchmark | Program page | Skipped alternatives |
|---|---|---|
| binarytrees | binarytrees-gcc-2.html | — |
| fannkuchredux | fannkuchredux-gcc-5.html | fannkuchredux-gcc-6.html:x86-simd:smmintrin.h/__m128/_mm_ |
| fasta | fasta-gcc-3.html | — |
| knucleotide | knucleotide-gcc-1.html | — |
| mandelbrot | mandelbrot-gcc-5.html | mandelbrot-gcc-6.html:x86-simd:emmintrin.h/__m128 |
| nbody | nbody-gcc-6.html | nbody-gcc-9.html:x86-simd:x86intrin.h/__m128/__m256,nbody-gcc-4.html:x86-simd:immintrin.h/__m128/_mm_ |
| pidigits | pidigits-gcc-2.html | — |
| regexredux | regexredux-gcc-5.html | — |
| revcomp | revcomp-gcc-6.html | revcomp-gcc-7.html:x86-simd:immintrin.h/__m128/_mm_,revcomp-gcc-9.html:musl-pthread-stack-overflow |
| spectralnorm | spectralnorm-gcc-4.html | spectralnorm-gcc-6.html:x86-simd:x86intrin.h/__m128/__m256,spectralnorm-gcc-5.html:x86-simd:emmintrin.h/__m128/_mm_,spectralnorm-gcc-7.html:x86-simd:x86intrin.h/__m128/_mm_ |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 0.12 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 0.07 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 0.03 |
| knucleotide | PASS | 136 | 15 | 2155388821:136 | 0.24 |
| mandelbrot | PASS | 1261 | 2 | 4144311493:1261 | 0.21 |
| nbody | PASS | 26 | 2 | 980964627:26 | 0.01 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 0.03 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 0.19 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 0.10 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 0.12 |

## Raw guest log tail

```text
__BG_BUILD:binarytrees
__BG_BUILD_RESULT:binarytrees:PASS
__BG_BUILD:fannkuchredux
__BG_BUILD_RESULT:fannkuchredux:PASS
__BG_BUILD:fasta
__BG_BUILD_RESULT:fasta:PASS
__BG_BUILD:knucleotide
__BG_BUILD_RESULT:knucleotide:PASS
__BG_BUILD:mandelbrot
__BG_BUILD_RESULT:mandelbrot:PASS
__BG_BUILD:nbody
__BG_BUILD_RESULT:nbody:PASS
__BG_BUILD:pidigits
__BG_BUILD_RESULT:pidigits:PASS
__BG_BUILD:regexredux
__BG_BUILD_RESULT:regexredux:PASS
__BG_BUILD:revcomp
__BG_BUILD_RESULT:revcomp:PASS
__BG_BUILD:spectralnorm
__BG_BUILD_RESULT:spectralnorm:PASS
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:0.12
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.07
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:0.03
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:0.24
__BG_RESULT:knucleotide:PASS:136:15:2155388821:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:0.21
__BG_RESULT:mandelbrot:PASS:1261:2:4144311493:1261
__BG_BEGIN:nbody
__BG_TIME:nbody:0.01
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:0.03
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.19
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.10
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:0.12
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
