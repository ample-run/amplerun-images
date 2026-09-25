# AmpleRun engine image: PyTorch (CUDA) classical workload over SSH — D-19
#
# Classical kind: no HTTP readiness; the renter reaches the container over
# the leased SSH endpoint (internal port 22). sshd runs AS the tenant user
# (10001) with host keys and authorized_keys under /work/.ssh.
# Multi-stage: the runtime stage only adds openssh-server to the pinned
# PyTorch CUDA runtime; the fetch stage exists to keep apt lists/caches out.
# Digest verified 2026-09-15 via hub.docker.com tag API.
ARG TORCH_RUNTIME=pytorch/pytorch:2.14.0-cuda12.6-cudnn9-runtime@sha256:a77983eb7a3042ccf41a94da547a7f54a47fb70da15c36d67a8e8a329ebaa098

FROM ${TORCH_RUNTIME} AS fetch
RUN apt-get update && apt-get download openssh-server openssh-sftp-server \
    && mkdir -p /out && mv ./*.deb /out/

FROM ${TORCH_RUNTIME}
COPY --from=fetch /out/*.deb /tmp/deb/
RUN apt-get update && apt-get install -y --no-install-recommends /tmp/deb/*.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/deb \
    && groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /bin/bash tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY sshd_config /etc/ssh/sshd_config.amplerun
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

ENV HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    XDG_CACHE_HOME=/work/.cache \
    SSH_PORT=22 \
    SSH_PUBLIC_KEY=""

USER 10001:10001
WORKDIR /work
EXPOSE 22
# ponytail: TCP-open on the SSH port is the readiness signal for classical
# kinds (the controller's SSH probe is the authority, T-08).
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${SSH_PORT}' || exit 1
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
