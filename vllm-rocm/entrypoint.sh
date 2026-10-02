#!/bin/sh
# vLLM OpenAI-compatible server. Env (all with defaults set in the image):
#   MODEL_DIR   local HF snapshot dir, read-only (host cache mount)
#   MODEL_ID    served model name (template_id)
#   MAX_MODEL_LEN, VLLM_QUANTIZATION (awq|gptq|fp8|...; empty = auto),
#   GPU_MEMORY_UTILIZATION
set -eu
mkdir -p "$TMPDIR" "$VLLM_CACHE_ROOT" "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR"
set -- python3 -m vllm.entrypoints.openai.api_server \
  --host 0.0.0.0 --port 8000 \
  --model "$MODEL_DIR" --served-model-name "$MODEL_ID" \
  --max-model-len "$MAX_MODEL_LEN" \
  --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
  --download-dir /work/hf
if [ -n "$VLLM_QUANTIZATION" ]; then
  set -- "$@" --quantization "$VLLM_QUANTIZATION"
fi
exec "$@"
