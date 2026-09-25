#!/bin/sh
# ComfyUI headless. Models come read-only from MODEL_DIR (host cache mount,
# subfolders per extra_model_paths.yaml); everything writable lives under
# /work. COMFY_ARGS appends extra flags (e.g. --lowvram for 16 GB cards).
set -eu
mkdir -p "$TMPDIR" /work/comfy/input /work/comfy/output /work/comfy/user
# shellcheck disable=SC2086
exec python /opt/ComfyUI/main.py \
  --listen 0.0.0.0 --port 8188 --disable-auto-launch \
  --input-directory /work/comfy/input \
  --output-directory /work/comfy/output \
  --user-directory /work/comfy/user \
  --temp-directory "$TMPDIR" \
  --extra-model-paths-config /opt/ComfyUI/extra_model_paths.yaml \
  $COMFY_ARGS
