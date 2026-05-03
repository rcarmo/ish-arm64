# Benchmarks Game Ruby smoke report

- Timestamp: 2026-05-03T13:30:29+00:00
- ish binary: /workspace/projects/ish-arm64/build-arm64-linux/ish
- rootfs: /workspace/projects/ish-arm64/alpine-arm64-fakefs
- timeout: 1200s
- guest workdir: /tmp/benchmarksgame-ruby-smoke
- Result: 10 / 10 passing

## Selected Ruby source variants

| Benchmark | Program page | Skipped alternatives |
|---|---|---|
| binarytrees | binarytrees-ruby-4.html | binarytrees-ruby-5.html:Thread/fork |
| fannkuchredux | fannkuchredux-ruby-1.html | fannkuchredux-ruby-2.html:Thread/fork |
| fasta | fasta-ruby-6.html | — |
| knucleotide | knucleotide-ruby-2.html | knucleotide-ruby-1.html:fork,knucleotide-ruby-7.html:Thread/fork |
| mandelbrot | mandelbrot-ruby-8.html | mandelbrot-ruby-5.html:Thread/fork,mandelbrot-ruby-2.html:fork,mandelbrot-ruby-4.html:Thread |
| nbody | nbody-ruby-3.html | — |
| pidigits | pidigits-ruby-1.html | — |
| regexredux | regexredux-ruby-9.html | regexredux-ruby-3.html:Thread/fork,regexredux-ruby-2.html:Thread |
| revcomp | revcomp-ruby-5.html | revcomp-ruby-4.html:Thread/fork,revcomp-ruby-3.html:Thread/fork,revcomp-ruby-1.html:Thread/fork |
| spectralnorm | spectralnorm-ruby-4.html | spectralnorm-ruby-5.html:fork |

## Results

| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |
|---|---:|---:|---:|---|---:|
| binarytrees | PASS | 144 | 4 | 3398443640:144 | 1.57 |
| fannkuchredux | PASS | 24 | 2 | 3876461884:24 | 1.59 |
| fasta | PASS | 10245 | 171 | 1573388369:10245 | 1.58 |
| knucleotide | PASS | 136 | 15 | 1370438066:136 | 2.38 |
| mandelbrot | PASS | 1311 | 2 | 2518315031:1311 | 3.82 |
| nbody | PASS | 26 | 2 | 980964627:26 | 1.71 |
| pidigits | PASS | 151 | 10 | 3273113594:151 | 1.74 |
| regexredux | PASS | 263 | 13 | 3404323976:263 | 1.62 |
| revcomp | PASS | 10174 | 168 | 2332509513:10174 | 1.56 |
| spectralnorm | PASS | 12 | 1 | 2938823901:12 | 3.18 |

## Raw guest log tail

```text
__BG_BEGIN:binarytrees
__BG_TIME:binarytrees:1.57
__BG_RESULT:binarytrees:PASS:144:4:3398443640:144
__BG_BEGIN:fannkuchredux
__BG_TIME:fannkuchredux:1.59
__BG_RESULT:fannkuchredux:PASS:24:2:3876461884:24
__BG_BEGIN:fasta
__BG_TIME:fasta:1.58
__BG_RESULT:fasta:PASS:10245:171:1573388369:10245
__BG_BEGIN:knucleotide
__BG_TIME:knucleotide:2.38
__BG_RESULT:knucleotide:PASS:136:15:1370438066:136
__BG_BEGIN:mandelbrot
__BG_TIME:mandelbrot:3.82
__BG_RESULT:mandelbrot:PASS:1311:2:2518315031:1311
__BG_BEGIN:nbody
__BG_TIME:nbody:1.71
__BG_RESULT:nbody:PASS:26:2:980964627:26
__BG_BEGIN:pidigits
__BG_TIME:pidigits:1.74
__BG_RESULT:pidigits:PASS:151:10:3273113594:151
__BG_BEGIN:regexredux
__BG_TIME:regexredux:1.62
__BG_RESULT:regexredux:PASS:263:13:3404323976:263
__BG_BEGIN:revcomp
__BG_TIME:revcomp:1.56
__BG_RESULT:revcomp:PASS:10174:168:2332509513:10174
__BG_BEGIN:spectralnorm
__BG_TIME:spectralnorm:3.18
__BG_RESULT:spectralnorm:PASS:12:1:2938823901:12
__BG_ALL_DONE

```
