#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ISH_BIN="${ISH_BIN:-$PROJECT_DIR/build-arm64-linux/ish}"
ROOTFS="${ROOTFS:-$PROJECT_DIR/alpine-arm64-fakefs}"
TIMEOUT_S="${TIMEOUT_S:-1200}"
REPORT_DIR="${REPORT_DIR:-/workspace/tmp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/benchmarksgame-gcc-smoke-$STAMP.md"
GUEST_WORK="/tmp/benchmarksgame-gcc-smoke"
HOST_TMP="$(mktemp -d)"

BENCHMARKS=(binarytrees fannkuchredux fasta knucleotide mandelbrot nbody pidigits regexredux revcomp spectralnorm)

cleanup() { rm -rf "$HOST_TMP"; }
trap cleanup EXIT
mkdir -p "$REPORT_DIR"

log() { printf '>>> %s\n' "$*"; }

guest_capture() {
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin; { $1; }; rc=\$?; printf '\n__ISH_STATUS:%s\n' \"\$rc\""
}

push_tree() {
    local src="$1" dst="$2"
    tar -C "$src" -cf - . | timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "rm -rf '$dst' && mkdir -p '$dst' && tar -xf - -C '$dst'"
}

ensure_guest_packages() {
    log "Ensuring GCC native benchmark dependencies in guest"
    local out="$HOST_TMP/ensure.log"
    guest_capture "apk add --no-cache build-base apr-dev gmp-dev pcre2-dev pcre-dev >/dev/null" >"$out" 2>&1
    grep -q '^__ISH_STATUS:0$' "$out"
}

fetch_sources() {
    log "Fetching Benchmarks Game GCC sources"
    HOST_TMP="$HOST_TMP" python3 - <<'PY'
import html, os, re, urllib.request
from pathlib import Path
site = "https://benchmarksgame-team.pages.debian.net/benchmarksgame"
benches = ["binarytrees", "fannkuchredux", "fasta", "knucleotide", "mandelbrot", "nbody", "pidigits", "regexredux", "revcomp", "spectralnorm"]
out = Path(os.environ["HOST_TMP"])
src_dir = out / "src"
src_dir.mkdir(parents=True, exist_ok=True)
variants = []

def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read().decode("utf-8", "replace")

def source_from_page(page):
    doc = fetch(f"{site}/program/{page}")
    pres = re.findall(r"<pre>(.*?)</pre>", doc, re.S)
    if not pres:
        raise RuntimeError(f"no source <pre> in {page}")
    return html.unescape(re.sub(r"<[^>]+>", "", pres[0])).replace("\ufeff", "")

arch_markers = (
    "immintrin.h", "x86intrin.h", "emmintrin.h", "smmintrin.h",
    "xmmintrin.h", "tmmintrin.h", "pmmintrin.h", "-mavx", "__m128",
    "__m256", "_mm_", "avx",
)
known_skip_pages = {
    # revcomp-gcc-9 uses a ~500 KiB VLA on each pthread stack. That is fine on
    # the Debian/glibc hosts used by the benchmark site, but overflows musl's
    # small default pthread stacks on Alpine. Keep the next official variant.
    "revcomp-gcc-9.html": "musl-pthread-stack-overflow",
}

for bench in benches:
    perf = fetch(f"{site}/performance/{bench}.html")
    pages = re.findall(r'\.\./program/(' + re.escape(bench) + r'-gcc-[^\"]+)', perf)
    if not pages:
        raise RuntimeError(f"no GCC page for {bench}")
    chosen_page = None
    chosen_source = None
    skipped = []
    for page in pages:
        source = source_from_page(page)
        hits = [m for m in arch_markers if m in source.lower()]
        if hits:
            skipped.append(page + ":x86-simd:" + "/".join(hits[:3]))
            continue
        if page in known_skip_pages:
            skipped.append(page + ":" + known_skip_pages[page])
            continue
        chosen_page = page
        chosen_source = source
        break
    if chosen_page is None:
        raise RuntimeError(f"no usable GCC page for {bench}")
    (src_dir / f"{bench}.c").write_text(chosen_source)
    variants.append((bench, chosen_page, ",".join(skipped)))

# knucleotide-gcc-1 uses the public-domain khash.h from klib. Alpine does not
# package this header separately, so fetch the expected upstream dependency.
(src_dir / "khash.h").write_text(fetch("https://raw.githubusercontent.com/attractivechaos/klib/master/khash.h"))

with (out / "variants.tsv").open("w") as f:
    for row in variants:
        f.write("\t".join(row) + "\n")
PY
}

prepare_guest() {
    push_tree "$HOST_TMP/src" "$GUEST_WORK/src"
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "mkdir -p '$GUEST_WORK/out'; cat > '$GUEST_WORK/run.sh'" <<'GUEST'
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd /tmp/benchmarksgame-gcc-smoke
mkdir -p out bin
ln -sf /proc/self/fd/0 /dev/stdin 2>/dev/null || true
for src in src/*.c; do
    name=${src##*/}; name=${name%.c}
    echo "__BG_BUILD:$name"
    gcc -O2 -pipe -I src -I/usr/include/apr-1 -fopenmp "$src" -o "bin/$name" \
        -lm -pthread -lapr-1 -lgmp -lpcre2-8 -lpcre
    echo "__BG_BUILD_RESULT:$name:PASS"
done
python3 - <<'PY' > input.fa
print('>THREE')
seq = 'ACGT' * 2500
for i in range(0, len(seq), 60):
    print(seq[i:i+60])
PY
run_arg() {
    name="$1"; arg="$2"
    echo "__BG_BEGIN:$name"
    /usr/bin/time -f "__BG_TIME:$name:%e" "bin/$name" "$arg" > "out/$name.out"
    bytes=$(wc -c < "out/$name.out"); lines=$(wc -l < "out/$name.out")
    cksum=$(cksum "out/$name.out" | awk '{print $1":"$2}')
    echo "__BG_RESULT:$name:PASS:$bytes:$lines:$cksum"
}
run_stdin() {
    name="$1"
    echo "__BG_BEGIN:$name"
    /usr/bin/time -f "__BG_TIME:$name:%e" "bin/$name" < input.fa > "out/$name.out"
    bytes=$(wc -c < "out/$name.out"); lines=$(wc -l < "out/$name.out")
    cksum=$(cksum "out/$name.out" | awk '{print $1":"$2}')
    echo "__BG_RESULT:$name:PASS:$bytes:$lines:$cksum"
}
run_arg binarytrees 7
run_arg fannkuchredux 7
run_arg fasta 1000
run_stdin knucleotide
run_arg mandelbrot 100
run_arg nbody 1000
run_arg pidigits 100
run_stdin regexredux
run_stdin revcomp
run_arg spectralnorm 100
echo "__BG_ALL_DONE"
GUEST
}

run_guest() {
    log "Running GCC Benchmarks Game smoke in guest"
    guest_capture "sh '$GUEST_WORK/run.sh'" >"$HOST_TMP/guest.log" 2>&1 || true
}

write_report() {
    local total_count pass_count build_count
    total_count=${#BENCHMARKS[@]}
    pass_count=$(grep -c '^__BG_RESULT:.*:PASS:' "$HOST_TMP/guest.log" || true)
    build_count=$(grep -c '^__BG_BUILD_RESULT:.*:PASS$' "$HOST_TMP/guest.log" || true)
    {
        echo "# Benchmarks Game GCC smoke report"
        echo
        echo "- Timestamp: $(date -Is)"
        echo "- ish binary: $ISH_BIN"
        echo "- rootfs: $ROOTFS"
        echo "- timeout: ${TIMEOUT_S}s"
        echo "- guest workdir: $GUEST_WORK"
        echo "- Build result: $build_count / $total_count passing"
        echo "- Result: $pass_count / $total_count passing"
        echo
        echo "## Selected GCC source variants"
        echo
        echo "| Benchmark | Program page | Skipped alternatives |"
        echo "|---|---|---|"
        while IFS=$'\t' read -r bench page skipped; do
            [ -n "$skipped" ] || skipped="—"
            echo "| $bench | $page | $skipped |"
        done < "$HOST_TMP/variants.tsv"
        echo
        echo "## Results"
        echo
        echo "| Benchmark | Status | Bytes | Lines | CRC:Size | Time (s) |"
        echo "|---|---:|---:|---:|---|---:|"
        for bench in "${BENCHMARKS[@]}"; do
            result=$(grep "^__BG_RESULT:$bench:" "$HOST_TMP/guest.log" | tail -1 || true)
            time_line=$(grep "^__BG_TIME:$bench:" "$HOST_TMP/guest.log" | tail -1 || true)
            elapsed="${time_line##*:}"
            if [ -n "$result" ]; then
                IFS=: read -r _ name status bytes lines checksum <<<"$result"
                echo "| $bench | $status | $bytes | $lines | $checksum | $elapsed |"
            else
                echo "| $bench | FAIL | 0 | 0 | — | — |"
            fi
        done
        echo
        echo "## Raw guest log tail"
        echo
        echo '```text'
        tail -220 "$HOST_TMP/guest.log" | sed '/^__ISH_STATUS:/d'
        echo '```'
    } >"$REPORT"
    echo "report: $REPORT"
    [ "$pass_count" -eq "$total_count" ] && [ "$build_count" -eq "$total_count" ]
}

ensure_guest_packages
fetch_sources
prepare_guest
run_guest
write_report
