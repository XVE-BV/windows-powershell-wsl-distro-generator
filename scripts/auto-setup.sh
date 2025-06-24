#!/usr/bin/env bash
set -euo pipefail

# 1) Ensure Docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable. Make sure Docker Desktop or WSL dockerd is running."
  exit 1
fi

# 2) Determine paths
display "🔍 Determining project root..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "🔨 Building and starting containers via: docker compose -f nginx-proxy-manager-compose.yml up -d"
# 3) Build (if needed) & start services
docker compose -f nginx-proxy-manager-compose.yml up -d

echo "✅ All containers are up."
