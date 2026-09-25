#!/bin/sh
# Speaches (faster-whisper) server. MODEL_ID selects the preloaded whisper
# model from the read-only HF cache; the server stays offline (HF_HUB_OFFLINE).
set -eu
mkdir -p "$TMPDIR"
export WHISPER__MODEL="$MODEL_ID"
exec uvicorn --factory speaches.main:create_app --host "$UVICORN_HOST" --port "$UVICORN_PORT"
