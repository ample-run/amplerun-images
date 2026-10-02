# AmpleRun engine image: vLLM on ROCm (OpenAI-compatible server) — D-19/D-23
#
# Twin of templates/images/vllm: same entrypoint and runtime contract
# (non-root 10001:10001, rootfs read-only, /work rw, /cache ro, serves
# 0.0.0.0:8000, HEALTHCHECK == readiness path /health), AMD base. vLLM's own
# ROCm image at the CUDA image's release (v0.29.0); the ROCm docs point at
# it (rocm.docs.amd.com, vLLM inference: docker pull vllm/vllm-openai-rocm).
# The GPU reaches the container only through the agent's ROCm launch
# profile (/dev/kfd, the allocated render node, the host's render GID).
#
# ponytail: single stage — the upstream image IS the runtime (ROCm, torch,
# vLLM); a builder stage would only copy a shell script.
# Digest verified 2026-09-25 via the registry API (Docker-Content-Digest
# equals the sha256 of the manifest bytes).
# NOT BUILT: ROCm images build only on deliberate dispatch
# (templates/README.md), never from images.yml.
FROM vllm/vllm-openai-rocm:v0.29.0@sha256:e5e47f6aaab675c252c381f0dac237b31b10d87bb74d092b07fb4065efd7f5a1

ENV HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    XDG_CACHE_HOME=/work/.cache \
    VLLM_CACHE_ROOT=/work/.cache/vllm \
    TORCHINDUCTOR_CACHE_DIR=/work/.cache/inductor \
    TRITON_CACHE_DIR=/work/.cache/triton \
    MODEL_DIR=/cache/model \
    MODEL_ID=model \
    MAX_MODEL_LEN=8192 \
    VLLM_QUANTIZATION="" \
    GPU_MEMORY_UTILIZATION=0.90

RUN groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

USER 10001:10001
WORKDIR /work
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=180s --retries=3 \
  CMD python3 -c "import sys,urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
