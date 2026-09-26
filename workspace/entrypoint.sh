#!/bin/sh
# Runtime half of the AmpleRun workspace wrapper. Runs as 10001:10001 under
# the launch profile: read-only rootfs, only /work writable, no capabilities.
# AMPLERUN_APP is baked in at build time (variants.json); the START template
# env supplies SSH_PUBLIC_KEY, the per-job AMPLERUN_API_KEY (and JUPYTER_TOKEN)
# and the model paths. Web UIs without their own authentication listen on
# 127.0.0.1 only and are reached through the SSH tunnel (ssh -L).
set -eu
mkdir -p "$TMPDIR" "$XDG_CACHE_HOME" /work/.ssh
chmod 700 /work/.ssh

start_sshd() { # "fg" keeps sshd in the foreground (SSH-only workspaces)
  if [ -n "${SSH_PUBLIC_KEY:-}" ] && [ ! -s /work/.ssh/authorized_keys ]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" > /work/.ssh/authorized_keys
    chmod 600 /work/.ssh/authorized_keys
  fi
  [ -f /work/.ssh/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -N "" -f /work/.ssh/ssh_host_ed25519_key
  # sshd starts sessions with a default PATH; hand them the image's toolchain.
  env | grep -E '^(PATH|LD_LIBRARY_PATH|PYTHONPATH|HOME|TMPDIR|HF_HOME|XDG_[A-Z_]+|CUDA_[A-Z_]+|CONDA_[A-Z_]+|VIRTUAL_ENV|MODEL_DIR|MODEL_ID)=' \
    > /work/.ssh/environment || true
  chmod 600 /work/.ssh/environment
  if [ "${1:-}" = fg ]; then
    exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config.amplerun -p "$SSH_PORT"
  fi
  /usr/sbin/sshd -e -f /etc/ssh/sshd_config.amplerun -p "$SSH_PORT" || echo "amplerun: sshd did not start" >&2
}

need_key() { # $1 = variable holding the controller's per-job credential
  eval "key=\${$1:-}"
  case "$key" in ''|*[!A-Za-z0-9_-]*) key= ;; esac
  if [ "${#key}" -ne 43 ]; then
    echo "amplerun: $AMPLERUN_APP requires a per-job runtime credential" >&2
    exit 64
  fi
}

comfy_models() { # COMFY_MODELS="folder=repo@revision:path ..." from the template env
  for item in ${COMFY_MODELS:-}; do
    folder=${item%%=*} rest=${item#*=}
    repo=${rest%%@*} rest=${rest#*@}
    rev=${rest%%:*} file=${rest#*:}
    hf download "$repo" "$file" --revision "$rev" --local-dir "/work/comfy/models/$folder" \
      || echo "amplerun: could not fetch $repo/$file" >&2
  done
}

case "$AMPLERUN_APP" in
  shell|llamacpp-cli|blender)
    start_sshd fg ;;
  jupyter)
    need_key JUPYTER_TOKEN # Jupyter reads it natively; never in argv or logs
    start_sshd
    exec jupyter lab --ip 0.0.0.0 --port 8000 --no-browser --ServerApp.root_dir=/work \
      --ServerApp.allow_remote_access=True --log-level=ERROR ;;
  code-server)
    need_key AMPLERUN_API_KEY
    start_sshd
    PASSWORD=$AMPLERUN_API_KEY exec code-server --bind-addr 0.0.0.0:8000 --auth password \
      --disable-telemetry --disable-update-check /work ;;
  vllm) # vLLM reads VLLM_API_KEY (set with AMPLERUN_API_KEY by the controller)
    need_key AMPLERUN_API_KEY
    exec vllm serve "$MODEL_DIR" --host 0.0.0.0 --port 8000 --served-model-name "$MODEL_ID" \
      --max-model-len "$MAX_MODEL_LEN" --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.90}" ;;
  sglang)
    need_key AMPLERUN_API_KEY
    exec python3 -m sglang.launch_server --model-path "$MODEL_DIR" --served-model-name "$MODEL_ID" \
      --host 0.0.0.0 --port 8000 --context-length "$MAX_MODEL_LEN" --api-key "$AMPLERUN_API_KEY" ;;
  tgi)
    need_key AMPLERUN_API_KEY
    API_KEY=$AMPLERUN_API_KEY exec text-generation-launcher --model-id "$MODEL_DIR" \
      --hostname 0.0.0.0 --port 8000 --max-total-tokens "$MAX_MODEL_LEN" --huggingface-hub-cache "$HF_HOME" ;;
  ollama)
    start_sshd
    OLLAMA_HOST=127.0.0.1:11434 OLLAMA_MODELS=/work/ollama/models exec ollama serve ;;
  open-webui) # start.sh also starts the bundled `ollama serve` (USE_OLLAMA_DOCKER=true)
    start_sshd
    mkdir -p /work/open-webui
    HOST=127.0.0.1 PORT=8080 DATA_DIR=/work/open-webui \
      WEBUI_SECRET_KEY_FILE=/work/open-webui/.webui_secret_key \
      SENTENCE_TRANSFORMERS_HOME="$XDG_CACHE_HOME/sentence-transformers" \
      TIKTOKEN_CACHE_DIR="$XDG_CACHE_HOME/tiktoken" exec bash /app/backend/start.sh ;;
  comfyui)
    start_sshd
    mkdir -p /work/comfy/models
    comfy_models > /work/comfy/models.log 2>&1 &
    exec python3 /opt/ComfyUI/main.py --listen 127.0.0.1 --port 8188 --base-directory /work/comfy \
      --disable-auto-launch ;;
  a1111|forge)
    start_sshd
    cd /opt/sdwebui
    exec python3 launch.py --skip-prepare-environment --skip-install --no-download-sd-model \
      --data-dir /work/sd --port 7860 ;;
  fooocus) # Fooocus writes next to its code, so it runs from a copy in /work
    start_sshd
    [ -d /work/fooocus ] || cp -a /content/app /work/fooocus
    cd /work/fooocus
    exec python3 launch.py --listen 127.0.0.1 --port 7865 ;;
  llamafactory)
    start_sshd
    [ -d /work/data ] || cp -a /app/data /work/data # LlamaBoard reads ./data/dataset_info.json
    GRADIO_SERVER_NAME=127.0.0.1 GRADIO_SERVER_PORT=7860 exec llamafactory-cli webui ;;
  speaches)
    need_key AMPLERUN_API_KEY
    start_sshd
    API_KEY=$AMPLERUN_API_KEY exec uvicorn --factory speaches.main:create_app --host 0.0.0.0 --port 8000 ;;
  kokoro)
    start_sshd
    mkdir -p /work/kokoro
    cd /app
    TEMP_FILE_DIR=/work/kokoro exec python -m uvicorn api.src.main:app --host 127.0.0.1 --port 8880 ;;
  *)
    echo "amplerun: unknown AMPLERUN_APP=$AMPLERUN_APP" >&2
    exit 64 ;;
esac
