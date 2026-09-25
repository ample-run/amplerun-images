#!/bin/sh
# llama-server (OpenAI-compatible). Env:
#   MODEL_DIR   read-only dir holding the GGUF (host cache mount)
#   MODEL_FILE  GGUF file name; empty = the single *.gguf in MODEL_DIR
#   MODEL_ID    alias reported by /v1/models; MAX_MODEL_LEN -> -c;
#   N_GPU_LAYERS -> -ngl (99 = everything on the GPU)
set -eu
mkdir -p "$TMPDIR"
if [ -z "$MODEL_FILE" ]; then
  set -- "$MODEL_DIR"/*.gguf
  [ "$#" -eq 1 ] && [ -f "$1" ] || { echo "MODEL_FILE unset and $MODEL_DIR has $# gguf files" >&2; exit 64; }
  MODEL_FILE=$(basename "$1")
fi
exec llama-server --host 0.0.0.0 --port 8000 \
  -m "$MODEL_DIR/$MODEL_FILE" --alias "$MODEL_ID" \
  -c "$MAX_MODEL_LEN" -ngl "$N_GPU_LAYERS" --no-webui
