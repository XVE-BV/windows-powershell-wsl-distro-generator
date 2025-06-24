#!/usr/bin/env bash
set -euo pipefail

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable."
  exit 1
fi

COMPOSE_FILE="/opt/nginx-proxy-manager/docker-compose.yml"
echo "🔨 Building and starting containers via: docker compose -f $COMPOSE_FILE up -d"
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ All set! Containers are up."
