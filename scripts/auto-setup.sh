#!/bin/bash
# Auto-setup script - runs once on first login, skips if already done

SETUP_FLAG="/tmp/.xve-setup-done"

# Check if setup already completed
if [ -f "$SETUP_FLAG" ]; then
    echo "✅ nginx-proxy-manager already set up and running"
    exit 0
fi

echo "🚀 First-time setup: Installing nginx-proxy-manager..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q '^xve-container$'; then
    echo "📦 Container already exists, starting it..."
    docker start xve-container
else
    echo "📦 Building and starting new container..."

    # Build image if it doesn't exist
    if ! docker images --format '{{.Repository}}' | grep -q '^xve-wsl$'; then
        echo "🔨 Building Docker image..."
        docker build -t xve-wsl .
    fi

    # Run container
    docker run -d \
      --name xve-container \
      --restart=unless-stopped \
      --privileged \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -p 8080:8080 -p 81:81 -p 8443:8443 \
      xve-wsl
fi

# Wait for nginx-proxy-manager to be ready
echo "⏳ Waiting for nginx-proxy-manager to be ready..."
timeout=60
counter=0
while ! curl -s http://localhost:81 >/dev/null 2>&1; do
    if [ $counter -ge $timeout ]; then
        echo "⚠️  nginx-proxy-manager ready check timed out"
        break
    fi
    sleep 2
    ((counter++))
done

# Mark setup as complete
touch "$SETUP_FLAG"

echo "✅ Setup complete!"
echo "📱 Admin panel: http://localhost:81"
echo "🌐 HTTP proxy: http://localhost:8080"
echo "🔒 HTTPS proxy: https://localhost:8443"
echo "🔑 Default login: admin@example.com / changeme"
echo ""
echo "This setup will not run again on future logins."