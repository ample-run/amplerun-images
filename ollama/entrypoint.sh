#!/bin/sh
# Ollama API on 0.0.0.0:8000; model store under the writable /work volume
# (ollama pulls at the renter's request — the host cache is not used here).
set -eu
mkdir -p "$TMPDIR" "$OLLAMA_MODELS"
exec ollama serve
