# Nginx Proxy Manager Setup for Laravel Sail

This guide explains how to set up Nginx Proxy Manager to work with your Laravel Sail project.

## Current Configuration

The `nginx-proxy-manager-compose.yml` has been configured with the following ports:
- **HTTP**: `8080:80` - Main proxy port
- **Admin Interface**: `8181:81` - Management dashboard
- **HTTPS**: `8443:443` - SSL proxy port

## Setup Steps

### 1. Start Nginx Proxy Manager

```bash
docker-compose -f nginx-proxy-manager-compose.yml up -d
```

### 2. Access Admin Interface

Open your browser and go to: `http://localhost:8181`

**Default credentials:**
- Email: `admin@example.com`
- Password: `changeme`

### 3. Configure Proxy Host

In the Nginx Proxy Manager admin interface:

1. Go to **Proxy Hosts** → **Add Proxy Host**
2. Fill in the details:
   - **Domain Names**: `sail-test-project.test`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `host.docker.internal`
   - **Forward Port**: `48080` (from your .env APP_PORT)
   - **Cache Assets**: Enable
   - **Block Common Exploits**: Enable

### 4. Update Your Hosts File

Make sure your `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows) contains:
```
127.0.0.1 sail-test-project.test
```

### 5. Access Your Application

After configuration, you can access your Laravel application at:
- **HTTP**: `http://sail-test-project.test:8080`
- **HTTPS**: `https://sail-test-project.test:8443` (after SSL setup)

## SSL Configuration (Optional)

To enable SSL:

1. In Nginx Proxy Manager, edit your proxy host
2. Go to the **SSL** tab
3. Choose **Request a new SSL Certificate**
4. Enable **Force SSL** and **HTTP/2 Support**

## Troubleshooting

### Common Issues

1. **Cannot connect to Laravel app**:
   - Ensure Laravel Sail is running: `./vendor/bin/sail up -d`
   - Check that port 48080 is accessible: `curl http://localhost:48080`

2. **Nginx Proxy Manager admin not accessible**:
   - Check if port 8181 is free: `netstat -an | grep 8181`
   - Restart the container: `docker-compose -f nginx-proxy-manager-compose.yml restart`

3. **Domain not resolving**:
   - Verify hosts file entry
   - Clear DNS cache: `ipconfig /flushdns` (Windows) or `sudo systemctl flush-dns` (Linux)

### Network Configuration

The configuration uses `host-gateway` to allow the Nginx Proxy Manager container to communicate with your Laravel Sail application running on the host network.

## Environment Variables Reference

Your Laravel `.env` file should have:
```env
APP_URL=http://sail-test-project.test:8080
APP_PORT=48080
```

For SSL setup, update to:
```env
APP_URL=https://sail-test-project.test:8443
```