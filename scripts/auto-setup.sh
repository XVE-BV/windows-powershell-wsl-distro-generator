#!/usr/bin/env bash
set -euo pipefail

# 1) Sanity check: Docker daemon must be reachable
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable. Make sure Docker Desktop (or WSL dockerd) is running."
  exit 1
fi

# 2) Change into the directory with your compose file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 3) Build (if needed) & start your services
echo "🔨 Building and starting containers via: docker compose up -d"
docker compose up -d

echo "✅ All set! Containers are up."
