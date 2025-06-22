#!/usr/bin/env bash
set -e

# Source your .wsl config or hard-code defaults
USER_NAME="xve"
USER_UID=1000
USER_GID=1000

# 1) Create the group & user on Ubuntu
if ! getent group "${USER_NAME}" >/dev/null; then
  groupadd --gid "${USER_GID}" "${USER_NAME}"
fi
if ! id -u "${USER_NAME}" >/dev/null; then
  useradd --create-home \
          --uid "${USER_UID}" \
          --gid "${USER_GID}" \
          --shell /bin/bash \
          "${USER_NAME}"
  apt-get update
  apt-get install -y sudo
  usermod -aG sudo "${USER_NAME}"
fi

# 2) Write /etc/wsl.conf on the host
cat > /etc/wsl.conf <<EOF
[user]
default=${USER_NAME}

[automount]
root = /
options = metadata,uid=${USER_UID},gid=${USER_GID}
EOF

echo "✅ /etc/wsl.conf written. Please run 'wsl --shutdown' in PowerShell to apply."
