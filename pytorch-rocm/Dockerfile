# AmpleRun engine image: PyTorch (ROCm) classical workload over SSH — D-19/D-23
#
# Twin of templates/images/pytorch: same sshd entrypoint and non-root
# runtime contract, AMD base. AMD's official ROCm PyTorch image: ROCm 10.0.0
# (the production release, 2026-08-26), PyTorch 2.13.0, Python 3.12 in
# /opt/venv, Ubuntu 24.04. The GPU reaches the container only through the
# agent's ROCm launch profile (--device /dev/kfd plus the allocated
# /dev/dri/renderD*, --group-add of the host's render GID).
# Digest verified 2026-09-25 via the registry API (Docker-Content-Digest
# equals the sha256 of the manifest bytes).
# NOT BUILT: ROCm images build only on deliberate dispatch
# (templates/README.md), never from images.yml.
ARG TORCH_RUNTIME=rocm/pytorch:rocm10.0_ubuntu24.04_py3.12_pytorch_release_2.13.0@sha256:bbdaba66029f905321be3bbc95206a2d9a56a2bc5300877d146ad24d40db9a12

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
