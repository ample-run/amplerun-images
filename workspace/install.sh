#!/bin/sh
# Build-time half of the AmpleRun workspace wrapper (runs as root, once).
# Adds the launch-profile contract to a pinned upstream image: the tenant
# user 10001:10001, a writable /work owned by it (the job volume copies this
# ownership on first mount), sshd, and the per-APP install below. Every
# download is pinned: git by commit (APP_REF), archives by sha256 (APP_SHA256).
set -eu

apt_install() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
  rm -rf /var/lib/apt/lists/*
}
fetch() { # URL SHA256 DEST: fails the build on any mismatch
  curl -fsSL --retry 3 -o "$3" "$1"
  echo "$2  $3" | sha256sum -c -
}
clone() { # URL COMMIT DEST: a detached checkout without history
  git clone --filter=blob:none "$1" "$3"
  git -C "$3" checkout --detach "$2"
  rm -rf "$3/.git"
}

command -v apt-get >/dev/null || { echo "workspace wrapper: base image must be Debian/Ubuntu" >&2; exit 1; }
apt_install openssh-server ca-certificates curl git
getent group 10001 >/dev/null || groupadd -g 10001 tenant
getent passwd 10001 >/dev/null || useradd -u 10001 -g 10001 -M -d /work -s /bin/bash tenant
mkdir -p /work /cache /run/sshd
chown 10001:10001 /work

export PIP_NO_CACHE_DIR=1 PIP_BREAK_SYSTEM_PACKAGES=1
# shellcheck disable=SC2086 # EXTRA_PIP is a list of pinned requirement specs
[ -z "$EXTRA_PIP" ] || python3 -m pip install $EXTRA_PIP

case "$APP" in
  comfyui)
    clone https://github.com/Comfy-Org/ComfyUI.git "$APP_REF" /opt/ComfyUI
    python3 -m pip install -r /opt/ComfyUI/requirements.txt ;;
  a1111|forge)
    clone "$APP_URL" "$APP_REF" /opt/sdwebui
    # Installs the pinned requirements and clones the helper repositories now,
    # so the read-only runtime never runs pip or git (--skip-prepare-environment).
    (cd /opt/sdwebui && python3 launch.py --skip-torch-cuda-test --no-download-sd-model --exit) ;;
  code-server)
    fetch "$APP_URL" "$APP_SHA256" /tmp/code-server.tar.gz
    mkdir -p /opt/code-server
    tar -xzf /tmp/code-server.tar.gz -C /opt/code-server --strip-components=1
    ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server
    rm /tmp/code-server.tar.gz ;;
  blender)
    apt_install xz-utils libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 libxkbcommon0 libsm6 libice6 libgl1 libegl1 libgomp1
    fetch "$APP_URL" "$APP_SHA256" /tmp/blender.tar.xz
    mkdir -p /opt/blender
    tar -xJf /tmp/blender.tar.xz -C /opt/blender --strip-components=1
    ln -s /opt/blender/blender /usr/local/bin/blender
    rm /tmp/blender.tar.xz ;;
  llamacpp-cli)
    # Upstream finds its libraries through the working directory (/app);
    # ours is /work, so register /app with the loader instead.
    echo /app > /etc/ld.so.conf.d/amplerun-llama.conf
    ldconfig
    for bin in /app/llama-*; do ln -sf "$bin" /usr/local/bin/; done ;;
  speaches)
    chmod 0755 /home/ubuntu ;; # the server and its venv live under a 0750 home
esac
