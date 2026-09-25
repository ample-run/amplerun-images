# AmpleRun engine image: ComfyUI headless (image/video diffusion) — D-19
#
# Multi-stage: the fetch stage clones ComfyUI at a pinned tag (git and the
# .git history never reach the runtime); the runtime installs the pinned
# requirements on top of the PyTorch CUDA runtime image. Serves 0.0.0.0:8188;
# readiness = GET /system_stats (200).
# Digest verified 2026-09-15 via hub.docker.com tag API.
ARG TORCH_RUNTIME=pytorch/pytorch:2.14.0-cuda12.6-cudnn9-runtime@sha256:a77983eb7a3042ccf41a94da547a7f54a47fb70da15c36d67a8e8a329ebaa098

FROM ${TORCH_RUNTIME} AS fetch
# comfyanonymous/ComfyUI v0.35.2, pinned by commit.
ARG COMFYUI_COMMIT=85eecc613aac153c2a3dfd6322434597c048ea05
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI && git checkout --detach "${COMFYUI_COMMIT}" && rm -rf .git

FROM ${TORCH_RUNTIME}
COPY --from=fetch /opt/ComfyUI /opt/ComfyUI
# ponytail: upstream requirements.txt pins are what ComfyUI tested against;
# torch, torchvision and torchaudio come from the base (already satisfied, not
# upgraded). The base's python3 is PEP 668 externally managed (run 35482664370
# failed on it); --break-system-packages installs next to PyTorch's own
# packages in /usr/local/lib/python3.12.
RUN pip install --no-cache-dir --break-system-packages -r /opt/ComfyUI/requirements.txt \
    && groupadd -g 10001 tenant && useradd -u 10001 -g 10001 -M -d /work -s /usr/sbin/nologin tenant \
    && mkdir -p /work /cache && chown -R 10001:10001 /work /opt/ComfyUI
COPY extra_model_paths.yaml /opt/ComfyUI/extra_model_paths.yaml
COPY --chmod=0755 entrypoint.sh /usr/local/bin/amplerun-entrypoint

ENV HF_HOME=/cache/hf \
    HF_HUB_OFFLINE=1 \
    HOME=/work \
    TMPDIR=/work/tmp \
    XDG_CACHE_HOME=/work/.cache \
    MODEL_DIR=/cache/model \
    COMFY_ARGS=""

USER 10001:10001
WORKDIR /work
EXPOSE 8188
HEALTHCHECK --interval=10s --timeout=3s --start-period=120s --retries=3 \
  CMD python -c "import sys,urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8188/system_stats', timeout=2).status == 200 else 1)"
ENTRYPOINT ["/usr/local/bin/amplerun-entrypoint"]
