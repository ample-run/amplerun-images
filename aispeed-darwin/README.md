# aispeed-darwin

The AI Speed probe for Apple silicon (`aispeed-darwin-v1`). A command-line
Swift tool, no Xcode project. The AmpleRun host agent runs it only when its
sha256 is pinned in `host-agent/aispeed-runtime.json` (signed with the agent
payload); unpinned, an Apple host reports no figures (null, never 0).

## Contract

It prints exactly one JSON line and exits 0:

```json
{"pci_address": "0000:00:00.0", "tflops_bf16": 7.21, "mem_bw_gbps": 188.16,
 "evidence": {"matmul_n": 4096, "matmul_s": [...], "copy_bytes": 1073741824,
              "copy_s": [...], "check": "pass"}}
```

- `pci_address`: `--pci <addr>`, default `0000:00:00.0` (the Apple sentinel).
- `tflops_bf16`: 2·N³ / median matmul time / 1e12, from 100 timed
  `MPSMatrixMultiplication` runs (N = 4096, after 20 warm-ups), each timed from
  `commit()` to `waitUntilCompleted()`.
- `mem_bw_gbps`: 2·bytes / median copy time / 1e9, from 10 timed blit copies
  between two private 1 GiB buffers (512 MiB when the GPU's recommended
  working set is under 4 GiB), after 3 warm-ups.
- `check`: a Freivalds check (C·x against A·(B·x) on the CPU in Float32,
  relative residual < 1e-2). On `fail` both figures are `null` and no timings run.
- Timings keep 6 decimals, figures 2.
- No Metal device: exit 2, no line.

**FP16 caveat.** Apple GPUs have no BF16 matmul path in MPS, so the figure is
FP16. It fills the `tflops_bf16` field because both are 16-bit training and
inference formats with the same matmul shape; do not compare it with an NVIDIA
BF16 tensor-core figure as like for like beyond that.

## Run by hand

```sh
swift build -c release --arch arm64 --package-path templates/images/aispeed-darwin
templates/images/aispeed-darwin/.build/arm64-apple-macosx/release/aispeed-darwin-arm64 --pci 0000:00:00.0
```

The public build is `.github/workflows/aispeed-darwin.yml` (GitHub-hosted
`macos-15`), published as the release asset `aispeed-<build>-darwin-arm64.tar.gz`
with its `.sha256`.
