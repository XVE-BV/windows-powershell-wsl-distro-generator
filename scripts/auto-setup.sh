#!/usr/bin/env bash
set -euo pipefail

# 1) Sanity check: Docker & Compose must be available
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable. Make sure Docker Desktop is running."
  exit 1
fi

if ! command -v docker-compose >/dev/null; then
  echo "❌ docker-compose not found. Install it or use 'docker compose' instead."
  exit 1
fi

# 2) Move into the folder with your compose file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 3) Launch (build + start) your stack
echo "🔨 Building and starting containers via Compose…"
docker-compose up -d

echo "✅ All set! Containers are up."
