#!/usr/bin/env bash
set -euo pipefail

# 1) Ensure Docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable. Make sure Docker Desktop or WSL dockerd is running."
  exit 1
fi

# 2) Determine script and project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is one level up from scripts directory
PROJECT_ROOT="${SCRIPT_DIR%/*}"
cd "$PROJECT_ROOT"

echo "🔍 Project root determined as: $PROJECT_ROOT"

echo "🔨 Building and starting containers via: docker compose -f nginx-proxy-manager-compose.yml up -d"
# 3) Build (if needed) & start services
if ! docker compose -f nginx-proxy-manager-compose.yml up -d; then
  echo "❌ Failed to build or start containers. Check errors above."
  exit 1
fi

echo "✅ All containers are up and running."
