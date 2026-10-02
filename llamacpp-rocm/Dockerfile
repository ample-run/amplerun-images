# AmpleRun engine image: llama.cpp server on ROCm/HIP (GGUF, OpenAI-compatible) — D-19/D-23
#
# Twin of templates/images/llamacpp: same entrypoint and runtime contract,
# AMD base: llama.cpp's own published HIP server image for the same build
# as the CUDA image. Its OCI labels read org.opencontainers.image.revision=
# 391fac16460f15233a7740550d858ac96df3419d and version b10969, as the CUDA
# image's do. Upstream (.devops/rocm.Dockerfile at that revision) builds on
# rocm/dev-ubuntu-24.04:7.2.1-complete for gfx908, gfx90a, gfx942, gfx1030,
# gfx1100-1102, gfx1150-1151 and gfx1200-1201, and notes that the ROCm user
# space "needs to generally match the container host's environment".
# The GPU reaches the container only through the agent's ROCm launch
# profile (/dev/kfd, the allocated render node, the host's render GID).
# Digest verified 2026-09-25 via the registry API (OCI index; sha256 of the
# manifest bytes equals Docker-Content-Digest).
# NOT BUILT: ROCm images build only on deliberate dispatch
# (templates/README.md), never from images.yml.
FROM ghcr.io/ggml-org/llama.cpp:server-rocm-b10969@sha256:f47149e51a45705232a4da1def1a69ee6e9406d80b4e1e0192746c37b0256511

RUN groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

# Upstream keeps llama-server and its libraries in /app (as in the CUDA
# image), so /app goes on PATH and on the library path explicitly.
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
