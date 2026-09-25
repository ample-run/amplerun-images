# AmpleRun engine image: faster-whisper via Speaches (OpenAI-compatible
# /v1/audio/transcriptions server, CTranslate2 backend) — D-19
#
# ponytail: single stage — Speaches is an existing OpenAI-compatible whisper
# server image; no stdlib HTTP wrapper of our own (out of scope).
# Digest verified 2026-09-15 via ghcr.io manifest API (OCI index).
#
# TODO(qualification): Speaches loads models through the Hugging Face hub
# cache, so a whisper template's read_only_mounts must target the HF cache
# layout under /cache/hf (models--Systran--faster-whisper-large-v3/...),
# not the flat /cache/model layout the other engines use. Confirm on
# spiry-2-lab before publishing `whisper-large-v3`.
FROM ghcr.io/speaches-ai/speaches:0.8.3-cuda-12.6.3@sha256:c0da392c37e76a01ba479239b43124c67baf8913ae0f491071d6ac544641dad7

ENV HF_HOME=/cache/hf \
    HF_HUB_CACHE=/cache/hf/hub \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    UVICORN_HOST=0.0.0.0 \
    UVICORN_PORT=8000 \
    MODEL_ID=Systran/faster-whisper-large-v3 \
    WHISPER__COMPUTE_TYPE=int8 \
    ENABLE_UI=false

# The base runs as `ubuntu` (uid 1000), so groupadd was refused (run
# 35482664370: "groupadd: Permission denied"). Its server, venv and uv-managed
# Python all live under /home/ubuntu, which ships 0750, so the tenant could not
# even start uvicorn: open it read/traverse to everyone.
USER root
RUN groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work && chmod 0755 /home/ubuntu
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

USER 10001:10001
WORKDIR /work
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=120s --retries=3 \
  CMD python -c "import sys,urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
