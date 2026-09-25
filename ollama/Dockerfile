# AmpleRun engine image: Ollama (classical; pulls models into /work) — D-19
#
# ponytail: single stage — the upstream image IS the runtime; we add curl
# for the HEALTHCHECK, the non-root tenant and the 0.0.0.0:8000 binding.
# Digest verified 2026-09-15 via hub.docker.com tag API.
FROM ollama/ollama:0.34.0@sha256:684d8674b4315fa18f4f0e973a118ec2652ed96f67563277839985175858e0ba

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

ENV HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    OLLAMA_HOST=0.0.0.0:8000 \
    OLLAMA_MODELS=/work/ollama/models \
    OLLAMA_KEEP_ALIVE=-1

USER 10001:10001
WORKDIR /work
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:8000/api/version || exit 1
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
