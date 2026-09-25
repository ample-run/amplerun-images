# AmpleRun engine image: llama.cpp server (GGUF, OpenAI-compatible) — D-19
#
# ponytail: single stage FROM llama.cpp's own published CUDA server image,
# pinned by index digest. Compiling llama.cpp with CUDA on the runner hit the
# 90-minute job limit (images run 35482664370). Same source as the old build:
# the image's OCI labels read org.opencontainers.image.revision=
# 391fac16460f15233a7740550d858ac96df3419d and version b10969, the commit this
# file compiled. Upstream builds every CUDA arch (the old build: sm_86/89 only)
# on CUDA 12.8.1 runtime (driver >= 570; the old base was 12.9.1, driver >= 575).
# Digest verified 2026-09-25 via the ghcr.io registry API (OCI index; sha256 of
# the manifest bytes equals Docker-Content-Digest).
FROM ghcr.io/ggml-org/llama.cpp:server-cuda-b10969@sha256:69c28827c1dc4807d00214e568b3187535bef7a2682825097a8357654084b49a

RUN groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

# Upstream keeps llama-server and its libraries in /app and finds the libraries
# through the working directory (RUNPATH "/app/build/bin:"); ours is /work, so
# /app goes on PATH and on the library path explicitly.
ENV PATH=/app:$PATH \
    LD_LIBRARY_PATH=/app:$LD_LIBRARY_PATH \
    HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    MODEL_DIR=/cache/model \
    MODEL_FILE="" \
    MODEL_ID=model \
    MAX_MODEL_LEN=8192 \
    N_GPU_LAYERS=99

USER 10001:10001
WORKDIR /work
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=120s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:8000/health || exit 1
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
