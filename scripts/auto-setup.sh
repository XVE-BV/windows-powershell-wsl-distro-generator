#!/usr/bin/env bash
set -euo pipefail

# Auto-setup script for initializing Nginx Proxy Manager in WSL
# Copies and builds are handled by Dockerfile; here we simply start the services.

# Marker to prevent re-running
SETUP_FLAG="/tmp/.xve-setup-done"
if [ -f "$SETUP_FLAG" ]; then
  echo "✅ nginx-proxy-manager already set up and running"
  exit 0
fi

# Ensure Docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon isn’t reachable. Make sure Docker Desktop or WSL dockerd is running."
  exit 1
fi

# Go to the directory where compose file was copied by Dockerfile
COMPOSE_DIR="/opt/nginx-proxy-manager"
if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
  echo "❌ Compose file not found at $COMPOSE_DIR/docker-compose.yml"
  exit 1
fi
cd "$COMPOSE_DIR"

echo "🔨 Starting Nginx Proxy Manager (no build step required)"
if ! docker compose up -d; then
  echo "❌ Failed to start containers. Check errors above."
  exit 1
fi

# Wait for admin interface
echo "⏳ Waiting for admin interface to become available..."
for i in {1..60}; do
  if curl -s http://localhost:81 >/dev/null 2>&1; then
    echo "🚀 nginx-proxy-manager is up!"
    break
  fi
  sleep 1
done

# Mark setup complete
touch "$SETUP_FLAG"

echo "✅ Setup complete!"
echo "🔑 Admin interface: http://localhost:8081"
echo "🌐 HTTP proxy: http://localhost:8080"
echo "🔒 HTTPS proxy: https://localhost:8443"
echo ""
echo "🔒 After login you'll be asked to modify your details and change your password."
echo "🔒 Default Admin User"
echo "🔒 username: admin@example.com"
echo "🔒 password: changeme"
echo ""
echo "suggestion to change password in prompt to: 00000000 and save in password manager"
echo ""
echo "for more info how configure .env of laravel projects and Nginx Proxy Manager:"
echo "https://youtu.be/N3uVU7To2Bc?si=U5Yp5Bfjffh6rILK&t=94"