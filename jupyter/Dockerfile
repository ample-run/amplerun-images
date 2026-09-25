# AmpleRun engine image: JupyterLab on PyTorch CUDA — D-19
#
# Multi-stage: the build stage pip-installs a pinned JupyterLab into an
# isolated prefix; the runtime stage copies only that prefix onto the pinned
# PyTorch CUDA runtime (no pip cache, no build leftovers). Serves
# 0.0.0.0:8000; readiness = GET /api (200, unauthenticated version probe).
# Digest verified 2026-09-15 via hub.docker.com tag API.
ARG TORCH_RUNTIME=pytorch/pytorch:2.14.0-cuda12.6-cudnn9-runtime@sha256:a77983eb7a3042ccf41a94da547a7f54a47fb70da15c36d67a8e8a329ebaa098

FROM ${TORCH_RUNTIME} AS build
ARG JUPYTERLAB_VERSION=4.6.3
RUN pip install --no-cache-dir --prefix=/opt/jupyter "jupyterlab==${JUPYTERLAB_VERSION}" ipykernel

FROM ${TORCH_RUNTIME}
COPY --from=build /opt/jupyter /opt/jupyter
RUN groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /bin/bash tenant \
    && mkdir -p /work /cache && chown 10001:10001 /work
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

ENV PATH=/opt/jupyter/bin:$PATH \
    HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    XDG_CACHE_HOME=/work/.cache \
    JUPYTER_CONFIG_DIR=/work/.jupyter \
    JUPYTER_DATA_DIR=/work/.local/share/jupyter \
    JUPYTER_RUNTIME_DIR=/work/.local/share/jupyter/runtime

USER 10001:10001
WORKDIR /work
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 \
  CMD python -c "import sys,urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api', timeout=2).status == 200 else 1)"
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
