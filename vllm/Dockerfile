# AmpleRun engine image: vLLM (OpenAI-compatible server) — D-19 / Phase 2.1
#
# Runtime contract (see templates/README.md): non-root 10001:10001, rootfs
# read-only, /work rw (tenant volume), /cache ro (host model cache mounts),
# serves 0.0.0.0:8000, HEALTHCHECK == template readiness path (/health).
#
# ponytail: single stage — the upstream image IS the runtime (CUDA 12.9,
# torch, vLLM); a builder stage would only copy a shell script.
# Digest verified 2026-09-15 via hub.docker.com tag API.
FROM vllm/vllm-openai:v0.29.0-cu129@sha256:7ef5a35d1ef8ce2cf9d671dd91eec6e367c5849262e0362b4d3d4a26be0d87d2

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
