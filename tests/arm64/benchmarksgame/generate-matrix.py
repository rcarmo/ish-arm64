#!/usr/bin/env python3
"""Generate the Benchmarks Game ARM64 iSH language matrix.

This is intentionally host-side and stdlib-only: it scrapes the current
Benchmarks Game performance pages plus Alpine aarch64 APKINDEX files, then
writes a Markdown matrix that accounts for every official language label.

It does not run the benchmarks yet. The generated report is the discovery /
feasibility input for the execution harness.
"""

from __future__ import annotations

import datetime as _dt
import gzip
import io
import re
import sys
import tarfile
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

SITE = "https://benchmarksgame-team.pages.debian.net/benchmarksgame"
REPOS = ("main", "community")
ALPINE_VERSION = "v3.23"
ARCH = "aarch64"

# Active Benchmarks Game families exposed through the performance pages. Keep
# this explicit so deleted/renamed site pages cause a visible script update.
BENCHMARKS = [
    "binarytrees",
    "fannkuchredux",
    "fasta",
    "knucleotide",
    "mandelbrot",
    "nbody",
    "pidigits",
    "regexredux",
    "revcomp",
    "spectralnorm",
]

# Official labels currently observed on the public pages, with Alpine aarch64
# feasibility notes. "ready-large" means package exists but install/runtime cost
# is large enough to keep out of the first core tier.
LANGUAGE_STATUS = {
    "gcc": ("ready", "gcc"),
    "gpp": ("ready", "g++"),
    "gnat": ("ready", "gcc-gnat"),
    "go": ("ready", "go"),
    "rust": ("ready-large", "rust/cargo"),
    "python3": ("ready", "python3"),
    "node": ("ready", "nodejs/npm"),
    "php": ("ready", "php84"),
    "perl": ("ready", "perl"),
    "ruby": ("ready", "ruby"),
    "lua": ("ready", "lua5.3/lua5.4; Benchmarks Game pidigits uses LGMP, which requires Lua < 5.4"),
    "ghc": ("ready-large", "ghc"),
    "ocaml": ("ready-large", "ocaml"),
    "sbcl": ("ready-large", "sbcl"),
    "racket": ("ready-large", "racket"),
    "csharpaot": ("partial/external", "dotnet packages exist; NativeAOT not verified"),
    "fsharpcore": ("partial/external", "dotnet packages exist; F# SDK/workload not verified"),
    "erlang": ("blocked/needs-investigation", "no obvious Erlang runtime in Alpine 3.23 aarch64 index"),
    "chapel": ("blocked", "no Alpine aarch64 package found"),
    "dartexe": ("blocked", "no Dart SDK package found"),
    "fpascal": ("blocked", "no Free Pascal package found"),
    "graalvmaot": ("blocked/external", "no GraalVM AOT package found"),
    "ifx": ("blocked", "Intel Fortran unavailable on Alpine/aarch64"),
    "julia": ("blocked", "no Alpine aarch64 package found"),
    "pharo": ("blocked", "no obvious Alpine package"),
    "swift": ("blocked", "no Swift package"),
}

STATUS_MARK = {
    "ready": "R",
    "ready-large": "L",
    "partial/external": "P",
    "blocked/needs-investigation": "?",
    "blocked/external": "X",
    "blocked": "X",
}


@dataclass(frozen=True)
class Variant:
    bench: str
    lang: str
    page: str


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def scrape_program_links() -> list[Variant]:
    variants: list[Variant] = []
    pattern = re.compile(r'href="\.\./program/([^"]+)"')
    for bench in BENCHMARKS:
        html = fetch(f"{SITE}/performance/{bench}.html").decode("utf-8", "replace")
        for page in pattern.findall(html):
            # Example: nbody-go-3.html, regexredux-csharpaot-5.html
            stem = page[:-5] if page.endswith(".html") else page
            m = re.match(rf"{re.escape(bench)}-(.+)-\d+$", stem)
            if not m:
                continue
            variants.append(Variant(bench=bench, lang=m.group(1), page=page))
    return variants


def fetch_apk_packages() -> dict[str, str]:
    packages: dict[str, str] = {}
    for repo in REPOS:
        url = f"http://dl-cdn.alpinelinux.org/alpine/{ALPINE_VERSION}/{repo}/{ARCH}/APKINDEX.tar.gz"
        try:
            blob = fetch(url)
        except Exception:
            continue
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tf:
            try:
                member = tf.extractfile("APKINDEX")
            except KeyError:
                continue
            if member is None:
                continue
            cur: dict[str, str] = {}
            for raw in member.read().decode("utf-8", "replace").splitlines():
                if not raw:
                    name = cur.get("P")
                    if name:
                        packages[name] = repo
                    cur = {}
                elif ":" in raw:
                    k, v = raw.split(":", 1)
                    cur[k] = v
            name = cur.get("P")
            if name:
                packages[name] = repo
    return packages


def build_report(variants: list[Variant], packages: dict[str, str]) -> str:
    by_lang = defaultdict(lambda: defaultdict(list))
    for variant in variants:
        by_lang[variant.lang][variant.bench].append(variant.page)

    langs = sorted(by_lang)
    unknown = [lang for lang in langs if lang not in LANGUAGE_STATUS]
    counts = Counter(v.lang for v in variants)
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()

    lines: list[str] = []
    lines.append("# Benchmarks Game ARM64 iSH success matrix")
    lines.append("")
    lines.append(f"Generated: {now}")
    lines.append("")
    lines.append("This is the discovery matrix for the next ARM64 iSH workload gate. It accounts for every official language/runtime label observed on the current Benchmarks Game performance pages and classifies whether each label is runnable with Alpine aarch64 packages, large-but-feasible, external/partial, or blocked.")
    lines.append("")
    lines.append("Legend:")
    lines.append("")
    lines.append("- `R` — source variant exists and the language is in the first runnable Alpine aarch64 tier.")
    lines.append("- `L` — source variant exists and the language has an Alpine package but is large/expensive; run after the core tier.")
    lines.append("- `P` — source variant exists but needs external/non-default setup before it can run.")
    lines.append("- `X` — source variant exists but no practical Alpine aarch64 toolchain is currently identified.")
    lines.append("- `?` — source variant exists but package/toolchain discovery needs investigation.")
    lines.append("- `—` — no program link for that benchmark/language label on the current site.")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Benchmarks: {len(BENCHMARKS)}")
    lines.append(f"- Official language labels observed: {len(langs)}")
    lines.append(f"- Program links observed: {len(variants)}")
    if unknown:
        lines.append(f"- Unknown labels needing table updates: {', '.join(unknown)}")
    else:
        lines.append("- Unknown labels needing table updates: none")
    lines.append("")

    status_counts = Counter(LANGUAGE_STATUS.get(lang, ("unknown", ""))[0] for lang in langs)
    lines.append("| Feasibility | Languages |")
    lines.append("|---|---:|")
    for status in ["ready", "ready-large", "partial/external", "blocked/needs-investigation", "blocked/external", "blocked", "unknown"]:
        if status_counts.get(status):
            lines.append(f"| {status} | {status_counts[status]} |")
    lines.append("")

    lines.append("## Language success matrix")
    lines.append("")
    header = ["Language", "Tier", "Variants"] + BENCHMARKS + ["Toolchain note"]
    lines.append("| " + " | ".join(header) + " |")
    lines.append("|" + "|".join(["---"] * len(header)) + "|")
    for lang in langs:
        status, note = LANGUAGE_STATUS.get(lang, ("unknown", "not classified"))
        mark = STATUS_MARK.get(status, "?")
        row = [lang, status, str(counts[lang])]
        for bench in BENCHMARKS:
            row.append(mark if by_lang[lang].get(bench) else "—")
        row.append(note)
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    lines.append("## Benchmark coverage by language count")
    lines.append("")
    lines.append("| Benchmark | Language labels with source variants |")
    lines.append("|---|---:|")
    for bench in BENCHMARKS:
        count = sum(1 for lang in langs if by_lang[lang].get(bench))
        lines.append(f"| {bench} | {count} |")
    lines.append("")

    lines.append("## Alpine package spot-check")
    lines.append("")
    package_names = ["gcc", "g++", "gcc-gnat", "go", "rust", "cargo", "python3", "nodejs", "npm", "php84", "perl", "ruby", "lua5.3", "lua5.4", "ghc", "ocaml", "sbcl", "racket", "mono", "dotnet-host"]
    lines.append("| Package | Repository |")
    lines.append("|---|---|")
    for pkg in package_names:
        lines.append(f"| {pkg} | {packages.get(pkg, 'not found')} |")
    lines.append("")

    lines.append("## Next execution tiers")
    lines.append("")
    lines.append("1. Core tier: `gcc`, `gpp`, `go`, `python3`, `node`, `php`, `perl`, `ruby`, `lua` across all 10 benchmarks with smoke-sized inputs.")
    lines.append("2. Compiler tier: add `gnat`, `rust`, `ghc`, `ocaml`, `sbcl`, `racket` once package install cost is acceptable.")
    lines.append("3. External tier: attempt .NET/F#, GraalVM, and other non-Alpine labels only after explicit toolchain setup.")
    lines.append("4. Blocked ledger: keep `X`/`?` labels in this matrix until they have a real runner or a documented reason they cannot run on Alpine aarch64.")
    lines.append("")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parents[3]
    output = root / "docs" / "BENCHMARKSGAME_MATRIX.md"
    if len(argv) > 1:
        output = Path(argv[1])

    variants = scrape_program_links()
    packages = fetch_apk_packages()
    output.write_text(build_report(variants, packages))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
