#!/bin/bash

# Function to check if port is in use
port_in_use() {
    ss -tuln 2>/dev/null | grep -q ":$1 " || netstat -tuln 2>/dev/null | grep -q ":$1 "
}

# Start Docker daemon
echo "Starting Docker daemon..."
dockerd > /var/log/dockerd.log 2>&1 &

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon..."
timeout=60
counter=0
while ! docker info >/dev/null 2>&1; do
    if [ $counter -ge $timeout ]; then
        echo "Docker daemon startup timed out"
        exit 1
    fi
    sleep 2
    ((counter++))
done
echo "Docker daemon is ready"

# Create nginx-proxy-manager data directories
mkdir -p /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt

# Check for port conflicts before starting
echo "Checking for port conflicts..."
conflicts=0
if port_in_use 8080; then
    echo "⚠️  Port 8080 is already in use - nginx-proxy-manager HTTP proxy may not work"
    conflicts=1
fi
if port_in_use 81; then
    echo "⚠️  Port 81 is already in use - nginx-proxy-manager admin interface may not work"
    conflicts=1
fi
if port_in_use 8443; then
    echo "⚠️  Port 8443 is already in use - nginx-proxy-manager HTTPS proxy may not work"
    conflicts=1
fi

if [ $conflicts -eq 0 ]; then
    echo "✅ No port conflicts detected"
fi

# Start nginx-proxy-manager
echo "Starting nginx-proxy-manager..."
cd /opt/nginx-proxy-manager && docker-compose up -d

# Wait for admin interface to be ready
echo "Waiting for nginx-proxy-manager admin interface..."
timeout=60
counter=0
while ! curl -s http://localhost:81 >/dev/null 2>&1; do
    if [ $counter -ge $timeout ]; then
        echo "nginx-proxy-manager admin interface ready check timed out"
        echo "Check logs with: docker-compose -f /opt/nginx-proxy-manager/docker-compose.yml logs"
        break
    fi
    sleep 2
    ((counter++))
done

echo "🚀 nginx-proxy-manager is running!"
echo "📱 Admin interface: http://localhost:81"
echo "🌐 HTTP proxy: http://localhost:8080 (routes to port 80 inside container)"
echo "🔒 HTTPS proxy: https://localhost:8443 (routes to port 443 inside container)"
echo "🔑 Default login: admin@example.com / changeme"
echo ""
echo "💡 To proxy Laravel Sail apps:"
echo "   - Add proxy host in admin panel"
echo "   - Forward to: http://host.docker.internal:80 (or whatever port Sail uses)"
echo "   - Use host.docker.internal to access WSL from container"

# Execute main command
exec "$@"