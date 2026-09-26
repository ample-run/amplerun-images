# AmpleRun workspace wrapper (catalog v2) — one Dockerfile, many images.
# NOT BUILT: images are built only by a deliberate `gh workflow run images.yml`.
#
# Each variant in templates/images/variants.json names a pinned upstream
# BASE (tag + digest, verified via the registry API) and the APP it runs.
# The wrapper adds only the launch-profile contract every template honours
# (templates/README.md): tenant 10001:10001, /work as the only writable path
# (owned by the tenant, so the job volume inherits it), caches under /work,
# sshd for the tenant on :22 with the renter's key from SSH_PUBLIC_KEY, and
# per-job credentials for every web UI or API that has authentication.
ARG BASE
FROM ${BASE}

ARG APP=shell
ARG EXTRA_PIP=""
ARG APP_URL=""
ARG APP_REF=""
ARG APP_SHA256=""

USER root
COPY install.sh /tmp/amplerun-install.sh
RUN APP="$APP" EXTRA_PIP="$EXTRA_PIP" APP_URL="$APP_URL" APP_REF="$APP_REF" APP_SHA256="$APP_SHA256" \
    sh /tmp/amplerun-install.sh && rm /tmp/amplerun-install.sh
COPY sshd_config /etc/ssh/sshd_config.amplerun
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

# Read-only rootfs: every path an app writes to lives on the /work volume.
ENV AMPLERUN_APP=${APP} \
    HOME=/work \
    TMPDIR=/work/tmp \
    XDG_CACHE_HOME=/work/.cache \
    XDG_CONFIG_HOME=/work/.config \
    XDG_DATA_HOME=/work/.local/share \
    HF_HOME=/work/.cache/huggingface \
    PIP_CACHE_DIR=/work/.cache/pip \
    PYTHONUSERBASE=/work/.local \
    MODEL_DIR=/cache/model \
    MODEL_ID=model \
    MAX_MODEL_LEN=8192 \
    SSH_PORT=22

USER 10001:10001
WORKDIR /work
EXPOSE 22
# ponytail: no HEALTHCHECK — readiness differs per APP and the host agent's
# probe of the template's readiness path is the authority (D-19(d)).
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
