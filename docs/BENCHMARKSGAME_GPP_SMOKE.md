# Benchmarks Game G++ smoke report

- Timestamp: 2026-05-04T06:58:02+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-gpp-smoke
- Build result: 10 / 10 passing
- Result: 10 / 10 passing

## Selected G++ source variants

| Benchmark | Program page | Skipped alternatives |
|---|---|---|
| binarytrees | binarytrees-gpp-7.html | — |
| fannkuchredux | fannkuchredux-gpp-4.html | fannkuchredux-gpp-6.html:x86-simd:immintrin.h/__m128/_mm_,fannkuchredux-gpp-5.html:source-portability-missing-cstdint |
| fasta | fasta-gpp-2.html | fasta-gpp-9.html:x86-simd:emmintrin.h/__m128/_mm_,fasta-gpp-7.html:musl-pthread-stack-overflow,fasta-gpp-5.html:musl-pthread-stack-overflow,fasta-gpp-6.html:musl-pthread-stack-overflow |
| knucleotide | knucleotide-gpp-2.html | — |
| mandelbrot | mandelbrot-gpp-0.html | mandelbrot-gpp-4.html:x86-simd:immintrin.h/__m128/__m256,mandelbrot-gpp-1.html:x86-simd:immintrin.h/__m128/__m256,mandelbrot-gpp-6.html:x86-simd:immintrin.h/__m128/__m256 |
| nbody | nbody-gpp-9.html | nbody-gpp-0.html:x86-simd:immintrin.h/__m128/__m256,nbody-gpp-7.html:x86-simd:immintrin.h/__m128/_mm_ |
| pidigits | pidigits-gpp-4.html | — |
| regexredux | regexredux-gpp-6.html | — |
| revcomp | revcomp-gpp-1.html | revcomp-gpp-2.html:x86-simd:immintrin.h/__m128/_mm_ |
| spectralnorm | spectralnorm-gpp-7.html | spectralnorm-gpp-6.html:x86-simd:emmintrin.h/__m128/_mm_,spectralnorm-gpp-5.html:x86-simd:emmintrin.h/__m128/_mm_ |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 0.13 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 0.05 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 0.05 |
| knucleotide | PASS | 89 | 10 | 3162668182:89 | 0.06 |
| mandelbrot | PASS | 1311 | 2 | 406860333:1311 | 0.09 |
| nbody | PASS | 25 | 2 | 16081251:25 | 0.01 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 0.05 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 0.06 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 0.02 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 0.21 |

## Raw guest log tail

```text
__BG_BUILD:binarytrees
__BG_BUILD_RESULT:binarytrees:PASS
__BG_BUILD:fannkuchredux
src/fannkuchredux.cpp: In member function 'Fannkuchredux::R Fannkuchredux::run(G*, int, int)':
src/fannkuchredux.cpp:96:26: warning: ISO C++17 does not allow 'register' storage class specifier [-Wregister]
   96 |             register int flips = 0;
      |                          ^~~~~
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
src/spectralnorm.cpp: In instantiation of 'v2dt eval_A_xmm(int, int) [with bool inc_i = false; v2dt = __vector(2) double]':
src/spectralnorm.cpp:109:34:   required from here
  109 |          sum += eval_A_xmm<false>(i, j) * p.xmm_u[j];
      |                 ~~~~~~~~~~~~~~~~~^~~~~~
src/spectralnorm.cpp:86:14: warning: narrowing conversion of 'd1' from 'int' to 'double' [-Wnarrowing]
   86 |    v2dt r = {d1, d2};
      |              ^~
src/spectralnorm.cpp:86:18: warning: narrowing conversion of 'd2' from 'int' to 'double' [-Wnarrowing]
   86 |    v2dt r = {d1, d2};
      |                  ^~
src/spectralnorm.cpp: In instantiation of 'v2dt eval_A_xmm(int, int) [with bool inc_i = true; v2dt = __vector(2) double]':
src/spectralnorm.cpp:128:33:   required from here
  128 |          sum += eval_A_xmm<true>(j, i) * p.xmm_tmp[j];
      |                 ~~~~~~~~~~~~~~~~^~~~~~
src/spectralnorm.cpp:86:14: warning: narrowing conversion of 'd1' from 'int' to 'double' [-Wnarrowing]
   86 |    v2dt r = {d1, d2};
      |              ^~
src/spectralnorm.cpp:86:18: warning: narrowing conversion of 'd2' from 'int' to 'double' [-Wnarrowing]
   86 |    v2dt r = {d1, d2};
      |                  ^~
__BG_BUILD_RESULT:spectralnorm:PASS
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:0.13
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:0.05
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:0.05
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:0.06
__BG_RESULT:knucleotide:PASS:89:10:3162668182:89
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:0.09
__BG_RESULT:mandelbrot:PASS:1311:2:406860333:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:0.01
__BG_RESULT:nbody:PASS:25:2:16081251:25
__BG_BEGIN:pidigits
__BG_TIME:pidigits:0.05
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:0.06
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:0.02
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:0.21
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
