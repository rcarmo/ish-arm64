#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ISH_BIN="${ISH_BIN:-$PROJECT_DIR/build-arm64-linux/ish}"
ROOTFS="${ROOTFS:-$PROJECT_DIR/alpine-arm64-fakefs}"
TIMEOUT_S="${TIMEOUT_S:-900}"
REPORT_DIR="${REPORT_DIR:-/workspace/tmp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/benchmarksgame-go-smoke-$STAMP.md"
GUEST_WORK="/tmp/benchmarksgame-go-smoke"
HOST_TMP="$(mktemp -d)"

BENCHMARKS=(binarytrees fannkuchredux fasta knucleotide mandelbrot nbody pidigits regexredux revcomp spectralnorm)

cleanup() {
    rm -rf "$HOST_TMP"
}
trap cleanup EXIT

mkdir -p "$REPORT_DIR"

log() {
    printf '>>> %s\n' "$*"
}

guest_capture() {
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin; { $1; }; rc=\$?; printf '\n__ISH_STATUS:%s\n' \"\$rc\""
}

push_tree() {
    local src="$1"
    local dst="$2"
    tar -C "$src" -cf - . | timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "rm -rf '$dst' && mkdir -p '$dst' && tar -xf - -C '$dst'"
}

fetch_sources() {
    log "Fetching Benchmarks Game Go sources"
    HOST_TMP="$HOST_TMP" python3 - <<'PY'
import html
import os
import re
import urllib.request
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
    return html.unescape(re.sub(r"<[^>]+>", "", pres[0]))

for bench in benches:
    perf = fetch(f"{site}/performance/{bench}.html")
    pages = re.findall(r'\.\./program/(' + re.escape(bench) + r'-go-[^\"]+)', perf)
    if not pages:
        raise RuntimeError(f"no Go page for {bench}")

    chosen_page = None
    chosen_source = None
    skipped = []
    for page in pages:
        source = source_from_page(page)
        # Keep this first smoke tier self-contained. The fastest Go variants for
        # pidigits/regexredux use cgo or third-party GMP/PCRE packages; those are
        # valuable later, but the first Go row should isolate iSH from external
        # dependency failures.
        if 'import "C"' in source or "github.com/" in source or "#cgo" in source:
            skipped.append(page)
            continue
        chosen_page = page
        chosen_source = source
        break
    if chosen_page is None:
        chosen_page = pages[0]
        chosen_source = source_from_page(chosen_page)

    (src_dir / f"{bench}.go").write_text(chosen_source)
    variants.append((bench, chosen_page, ",".join(skipped)))

with (out / "variants.tsv").open("w") as f:
    for row in variants:
        f.write("\t".join(row) + "\n")
PY
}

prepare_guest() {
    push_tree "$HOST_TMP/src" "$GUEST_WORK/src"
    timeout "$TIMEOUT_S" "$ISH_BIN" -f "$ROOTFS" /bin/sh -c "mkdir -p '$GUEST_WORK/bin' '$GUEST_WORK/out'; cat > '$GUEST_WORK/run.sh'" <<'GUEST'
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export HOME=/root
export GOMAXPROCS=${GOMAXPROCS:-2}
export GODEBUG=${GODEBUG:-asyncpreemptoff=1}
cd /tmp/benchmarksgame-go-smoke
mkdir -p bin out
ln -sf /proc/self/fd/0 /dev/stdin 2>/dev/null || true
python3 - <<'PY' > input.fa
print('>THREE')
seq = 'ACGT' * 2500
for i in range(0, len(seq), 60):
    print(seq[i:i+60])
PY
run_arg() {
    name="$1"
    arg="$2"
    echo "__BG_BEGIN:$name"
    go build -trimpath -o "bin/$name" "src/$name.go"
    /usr/bin/time -f "__BG_TIME:$name:%e" "bin/$name" "$arg" > "out/$name.out"
    bytes=$(wc -c < "out/$name.out")
    lines=$(wc -l < "out/$name.out")
    cksum=$(cksum "out/$name.out" | awk '{print $1":"$2}')
    echo "__BG_RESULT:$name:PASS:$bytes:$lines:$cksum"
}
run_stdin() {
    name="$1"
    echo "__BG_BEGIN:$name"
    go build -trimpath -o "bin/$name" "src/$name.go"
    /usr/bin/time -f "__BG_TIME:$name:%e" "bin/$name" < input.fa > "out/$name.out"
    bytes=$(wc -c < "out/$name.out")
    lines=$(wc -l < "out/$name.out")
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
    log "Running Go Benchmarks Game smoke in guest"
    guest_capture "sh '$GUEST_WORK/run.sh'" >"$HOST_TMP/guest.log" 2>&1 || true
}

write_report() {
    local pass_count total_count
    total_count=${#BENCHMARKS[@]}
    pass_count=$(grep -c '^__BG_RESULT:.*:PASS:' "$HOST_TMP/guest.log" || true)

    {
        echo "# Benchmarks Game Go smoke report"
        echo
        echo "- Timestamp: $(date -Is)"
        echo "- ish binary: $ISH_BIN"
        echo "- rootfs: $ROOTFS"
        echo "- timeout: ${TIMEOUT_S}s"
        echo "- guest workdir: $GUEST_WORK"
        echo "- Result: $pass_count / $total_count passing"
        echo
        echo "## Selected Go source variants"
        echo
        echo "| Benchmark | Program page | Skipped self-contained alternatives |"
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
        tail -120 "$HOST_TMP/guest.log" | sed '/^__ISH_STATUS:/d'
        echo '```'
    } >"$REPORT"

    echo "report: $REPORT"
    [ "$pass_count" -eq "$total_count" ]
}

fetch_sources
prepare_guest
run_guest
write_report
