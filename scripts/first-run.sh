#!/bin/bash
# First-run setup script - run this once after importing WSL

echo "🚀 Starting nginx-proxy-manager container..."

docker run -d \
  --name nginx-proxy-manager \
  --restart=unless-stopped \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 8080:8080 -p 81:81 -p 8443:8443 \
  your-wsl-image

echo "✅ nginx-proxy-manager is now running in background"
echo "📱 Admin: http://localhost:81"
echo "🌐 HTTP proxy: http://localhost:8080"
echo "🔒 HTTPS proxy: https://localhost:8443"
echo ""
echo "Container will auto-start with WSL thanks to --restart=unless-stopped"