#!/bin/bash
# sshd as the tenant user. SSH_PUBLIC_KEY (renter key from START) seeds
# /work/.ssh/authorized_keys on first start; host keys persist in /work.
set -eu
mkdir -p "$TMPDIR" /work/.ssh && chmod 700 /work/.ssh
if [ -n "$SSH_PUBLIC_KEY" ] && [ ! -s /work/.ssh/authorized_keys ]; then
  printf '%s\n' "$SSH_PUBLIC_KEY" > /work/.ssh/authorized_keys
  chmod 600 /work/.ssh/authorized_keys
fi
[ -f /work/.ssh/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -N "" -f /work/.ssh/ssh_host_ed25519_key
# ponytail: port 22 needs CAP_NET_BIND_SERVICE effective for a non-root
# process, which no-new-privileges + drop-all denies; if qualification shows
# EACCES, add `--sysctl net.ipv4.ip_unprivileged_port_start=0` to the
# launch profile (runtime.build_create_argv) rather than running as root.
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config.amplerun -p "$SSH_PORT"
