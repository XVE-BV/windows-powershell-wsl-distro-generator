#!/bin/sh
set -e

# Only run once per user
MARKER="$HOME/.gpg_pass_initialized"
if [ -f "$MARKER" ]; then
  exit 0
fi

echo "🔑 Checking for existing GPG keys..."
if gpg --list-secret-keys --with-colons | grep -q '^sec'; then
  echo "   ✔️  GPG key already exists, skipping generation."
else
  echo "   ➕ Generating a new GPG key WITHOUT a passphrase for local dev..."
  # you can customize Name/Email here or prompt if you like:
  GPG_NAME="${GIT_AUTHOR_NAME:-Your Name}"
  GPG_EMAIL="${GIT_AUTHOR_EMAIL:-you@example.com}"

  gpg --batch --generate-key <<EOF
%no-protection
Key-Type: default
Subkey-Type: default
Name-Real: $GPG_NAME
Name-Email: $GPG_EMAIL
Expire-Date: 0
EOF

  echo "   ✔️  GPG key generated."
fi

# Always grab the first key’s fingerprint
GPG_KEY=$(gpg --list-keys --with-colons | awk -F: '/^pub/ {print $5; exit}')

if [ -z "$GPG_KEY" ]; then
  echo "Failed to find GPG key fingerprint. Aborting."
  exit 1
fi

echo "   🔧 Initializing pass store with key $GPG_KEY..."
pass init "$GPG_KEY"

touch "$MARKER"
echo "GPG & pass are ready (no passphrase key)."
