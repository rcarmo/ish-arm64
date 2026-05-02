# go-gte progress on ARM64 iSH

Date: 2026-05-02
Updated: 2026-05-02 22:35 UTC

## Goal

Install and run `https://github.com/rcarmo/go-gte` inside the ARM64 iSH Linux-host fakefs, then record how far the modern Go + Python + SIMD workload gets.

## Environment

- Host: Orange Pi 6 Plus, Debian Trixie, AArch64
- Emulator: `build-arm64-linux/ish`
- Rootfs: `alpine-arm64-fakefs`
- Guest kernel banner: `Linux orangepi6plus 4.20.69-ish ... aarch64`
- Guest Go: `go version go1.25.9 linux/arm64`
- go-gte commit tested: `b76c36a`
- Conservative guest runtime env used for Go workloads:
  - `GOMAXPROCS=2`
  - `GODEBUG=asyncpreemptoff=1`
  - `CGO_ENABLED=0`

## Install path

Guest packages and Python dependencies installed successfully:

```sh
apk add --no-cache git make ca-certificates
python3 -m pip install --break-system-packages --no-cache-dir safetensors requests numpy
```

Repository clone succeeded inside the guest:

```sh
cd /tmp
git clone --depth 1 https://github.com/rcarmo/go-gte.git
cd /tmp/go-gte
git rev-parse --short HEAD   # b76c36a
```

Manual Go builds of the existing commands succeeded:

```sh
go build -trimpath -o /usr/local/bin/gte ./cmd/gte
go build -trimpath -o /usr/local/bin/gte-bench ./cmd/bench
go build -trimpath -o /usr/local/bin/gte-jitter ./cmd/jitter
```

Installed guest artifacts:

```text
/usr/local/bin/gte          2.5M
/usr/local/bin/gte-bench    2.9M
/usr/local/bin/gte-jitter   2.6M
/tmp/go-gte/gte-small.gtemodel 127.5M
```

Guest-side model conversion now succeeds after adding AdvSIMD `FCVTL`/`FCVTL2` support to iSH. A host-generated model was used only as a temporary workaround before that emulator fix.

## Working result

Guest-side model conversion now completes:

```sh
python3 convert_model.py models/gte-small gte-small.gtemodel
```

Observed result:

```text
Model saved to gte-small.gtemodel
File size: 127.51 MB
CONVERT_RC:0
```

`make run-go` now completes inside ARM64 iSH:

```sh
make run-go
```

Observed output summary:

```text
Model loaded in 5.64 s
Embedding dimension: 384
Max sequence length: 512

"I love cats"                  375.397 ms
"I love dogs"                  373.794 ms
"The stock market crashed"     385.561 ms

Cosine similarity matrix:
S1/S2: 0.898
S1/S3: 0.727
S2/S3: 0.722
```

The benchmark command also runs:

```sh
/usr/local/bin/gte-bench --model-path /tmp/go-gte/gte-small.gtemodel --iterations 3 --warmup 1
```

Observed result:

```text
Model loaded in 7.320 s
Total calls: 15
Total time: 6.214 s
Average per embedding: 414.256 ms
Throughput: 2.4 embeddings/s
```

## Failures and gaps exposed

### 1. Upstream Makefile references a missing command directory

`make go-build` currently fails independently of iSH because the Makefile tries to build `./cmd/test_gte`, which is not present in the tested checkout:

```text
go build -trimpath ./cmd/gte ./cmd/test_gte ./cmd/bench
stat /tmp/go-gte/cmd/test_gte: directory not found
make: *** [Makefile:26: go-build] Error 1
```

Manual builds of existing command directories work.

### 2. Guest-side model conversion previously hit missing ARM64 SIMD FP16 conversion — fixed

The first conversion attempt trapped with:

```text
illegal instruction at 0xeabf23e4: insn=0x0e217bfe
```

Decoded instruction:

```asm
fcvtl v30.4s, v31.4h
```

This is ARM64 AdvSIMD FP16-to-FP32 widening conversion. iSH now decodes and executes `FCVTL`/`FCVTL2` for H→S and S→D vector widening, and the conversion step succeeds in guest.

### 3. Go ARM64 SIMD low-level `SgemmNT` tests still fail

`go test ./...` reaches package tests, but the optimized ARM64 SIMD package fails:

```text
ok   github.com/rcarmo/gte-go/gte 0.175s
FAIL github.com/rcarmo/gte-go/gte/simd
```

Representative failures:

```text
--- FAIL: TestSgemmNTIdentity
    C[1,1]=0, want 1
    C[2,2]=0, want 1
    C[3,3]=0, want 1

--- FAIL: TestSgemmNTSmall
    C[0]=2, want 10
    C[1]=0, want 4
    ...

--- FAIL: TestSgemmNTGTESizes/QKV_fused
    maxErr=2.6212463 > tol=0.001 (m=7 n=1152 k=384)
```

Focused high-level ARM64 paths used by go-gte now pass (`SgemmNN`, `SgemmNTGebp`, packing, `Sdot`, `Saxpy`). The remaining failures are in the direct low-level `SgemmNT` Plan 9 assembly tests; inspection shows that routine horizontally reduces into `F20` but later stores/scales `F0`, so this may be a go-gte assembly bug rather than an iSH bug. Keep it in the smoke test until either upstream is fixed or an iSH counterexample is found.

## Logs

- `/workspace/tmp/go-gte-ish-preflight.log`
- `/workspace/tmp/go-gte-ish-install.log`
- `/workspace/tmp/go-gte-ish-build-run.log`
- `/workspace/tmp/go-gte-ish-run-hostmodel.log`
- `/workspace/tmp/go-gte-ish-final-copy.log`
- `/workspace/tmp/fcvtl-smoke.log`
- `/workspace/tmp/go-gte-convert-after-fcvtl.log`
- `/workspace/tmp/go-gte-make-run-go-after-fcvtl.log`
- `/workspace/tmp/go-gte-simd-focused.log`

## Next steps

1. Decide how to handle go-gte upstream issues for a truly one-command `make` path:
   - Makefile references missing `./cmd/test_gte`;
   - direct low-level `SgemmNT` appears to use the wrong FP accumulator after horizontal reduction.
2. Add a focused runtime test that runs the go-gte smoke path separately from the broad runtime-coverage gate:
   - clone;
   - install Python deps;
   - build existing Go commands;
   - guest model conversion;
   - `make run-go`;
   - focused SIMD tests for `SgemmNN`, `SgemmNTGebp`, pack, `Sdot`, `Saxpy`.
3. If upstream go-gte is patched, rerun `go test ./...` as the final all-green gate.
