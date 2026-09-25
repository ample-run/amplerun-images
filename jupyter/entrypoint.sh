#!/bin/sh
# Only the controller's per-job credential enables notebook startup.
# Jupyter reads JUPYTER_TOKEN natively; never put it in argv or startup logs.
set -eu
case "${JUPYTER_TOKEN:-}" in
  ''|*[!A-Za-z0-9_-]*) echo 'Jupyter requires a per-job runtime credential.' >&2; exit 64 ;;
esac
[ "${#JUPYTER_TOKEN}" -eq 43 ] || { echo 'Jupyter requires a per-job runtime credential.' >&2; exit 64; }
unset JUPYTER_TOKEN_FILE
umask 077
mkdir -p "$TMPDIR" "$JUPYTER_CONFIG_DIR" "$JUPYTER_RUNTIME_DIR"
PYTHONPATH=$(ls -d /opt/jupyter/lib/python3.*/site-packages 2>/dev/null | head -n 1)
export PYTHONPATH
exec jupyter lab --ip 0.0.0.0 --port 8000 --no-browser \
  --ServerApp.root_dir=/work --log-level=ERROR \
  --ServerApp.allow_remote_access=True
