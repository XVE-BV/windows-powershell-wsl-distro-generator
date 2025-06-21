FROM php:8.4-fpm-alpine as builder

# Install build dependencies
RUN apk add --no-cache $PHPIZE_DEPS \
    imagemagick-dev icu-dev zlib-dev jpeg-dev libpng-dev libzip-dev postgresql-dev libgomp linux-headers

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg
RUN docker-php-ext-install intl pcntl gd exif zip mysqli pgsql pdo pdo_mysql pdo_pgsql bcmath opcache

# Install xdebug extension
RUN pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    echo "xdebug.mode=coverage" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install imagick extension (workaround)
ARG IMAGICK_VERSION=3.7.0
RUN curl -L -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/tags/${IMAGICK_VERSION}.tar.gz && \
    cd /tmp && tar --strip-components=1 -xf imagick.tar.gz && \
    sed -i 's/php_strtolower/zend_str_tolower/g' imagick.c && \
    phpize && ./configure && make && make install && \
    echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini && \
    rm -rf /tmp/*

# Clean up build dependencies
RUN apk del $PHPIZE_DEPS imagemagick-dev icu-dev zlib-dev jpeg-dev libpng-dev libzip-dev postgresql-dev libgomp

# Final image
FROM php:8.4-fpm-alpine
LABEL maintainer="XVE Development Distribution"

ARG APP_ID=1000
ARG TARGETARCH=amd64

# Copy PHP extensions and configs from builder
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Install runtime dependencies and system packages
RUN apk add --no-cache \
    # PHP runtime deps
    libpng libpq zip jpeg libzip imagemagick icu \
    # System tools
    bash curl git nano vim sudo openssl nss-tools sqlite nodejs npm ncdu \
    # Nginx
    nginx linux-headers

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create app user with sudo privileges
RUN addgroup -g "$APP_ID" app && \
    adduser -G app -u "$APP_ID" -h /var/www -s /bin/bash -S app && \
    echo 'app ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Create necessary directories
RUN mkdir -p /etc/nginx/certs /var/www/html /run/nginx /var/log/nginx /run/php

# Generate self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/nginx.key \
    -out /etc/nginx/certs/nginx.crt \
    -subj "/C=US/ST=Local/L=Local/O=WSL/CN=localhost"

# Install mkcert for local development
RUN cd /usr/local/bin/ && \
    curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-${TARGETARCH} -o mkcert && \
    chmod +x mkcert

# Configure PHP-FPM to use socket (matching your nginx config)
RUN echo '[global]' > /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'error_log = /var/log/php-fpm.log' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo '' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo '[www]' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'user = app' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'group = app' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'listen = /run/php-fpm.sock' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'listen.owner = app' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'listen.group = app' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'listen.mode = 0660' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'pm = dynamic' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'pm.max_children = 10' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'pm.start_servers = 2' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'pm.min_spare_servers = 1' >> /usr/local/etc/php-fpm.d/zz-socket.conf && \
    echo 'pm.max_spare_servers = 3' >> /usr/local/etc/php-fpm.d/zz-socket.conf

# Create WSL config to default to app user
RUN echo '[user]' > /etc/wsl.conf && \
    echo 'default=app' >> /etc/wsl.conf

# Custom branding - replace Alpine references
RUN echo 'NAME="XVE Development Linux"' > /etc/os-release && \
    echo 'VERSION="1.0"' >> /etc/os-release && \
    echo 'ID=xve' >> /etc/os-release && \
    echo 'PRETTY_NAME="XVE Development Environment"' >> /etc/os-release && \
    echo 'VERSION_ID="1.0"' >> /etc/os-release && \
    echo 'HOME_URL="https://your-domain.com"' >> /etc/os-release && \
    echo 'SUPPORT_URL="https://your-domain.com/support"' >> /etc/os-release

# Copy XVE logo script
COPY scripts/show-xve-logo.sh /usr/local/bin/show-xve-logo
RUN chmod +x /usr/local/bin/show-xve-logo

# Custom login banner
RUN echo 'Welcome to XVE Development Environment' > /etc/motd && \
    echo 'PHP 8.4 + Nginx + Development Tools' >> /etc/motd && \
    echo '' >> /etc/motd

# Remove Alpine branding
RUN rm -f /etc/issue.old /etc/alpine-release /usr/lib/os-release 2>/dev/null || true

# Block neofetch from autorunning
RUN sed -i '/neofetch/d' /etc/profile /etc/bash.bashrc 2>/dev/null || true

# Create startup script
RUN echo '#!/bin/bash' > /usr/local/bin/start-web && \
    echo 'set -e' >> /usr/local/bin/start-web && \
    echo '' >> /usr/local/bin/start-web && \
    echo '# Ensure directories exist' >> /usr/local/bin/start-web && \
    echo 'sudo mkdir -p /run/nginx /var/log/nginx /run/php' >> /usr/local/bin/start-web && \
    echo 'sudo chown app:app /run/nginx /var/log/nginx /run/php' >> /usr/local/bin/start-web && \
    echo '' >> /usr/local/bin/start-web && \
    echo '# Generate trusted certificates if mkcert is available' >> /usr/local/bin/start-web && \
    echo 'if [ ! -f /etc/nginx/certs/mkcert.crt ]; then' >> /usr/local/bin/start-web && \
    echo '  if command -v mkcert >/dev/null 2>&1; then' >> /usr/local/bin/start-web && \
    echo '    mkcert -install 2>/dev/null || true' >> /usr/local/bin/start-web && \
    echo '    mkcert -cert-file /tmp/cert.pem -key-file /tmp/key.pem localhost 127.0.0.1 ::1 2>/dev/null || true' >> /usr/local/bin/start-web && \
    echo '    if [ -f /tmp/cert.pem ]; then' >> /usr/local/bin/start-web && \
    echo '      sudo cp /tmp/cert.pem /etc/nginx/certs/nginx.crt' >> /usr/local/bin/start-web && \
    echo '      sudo cp /tmp/key.pem /etc/nginx/certs/nginx.key' >> /usr/local/bin/start-web && \
    echo '      sudo touch /etc/nginx/certs/mkcert.crt' >> /usr/local/bin/start-web && \
    echo '      rm -f /tmp/cert.pem /tmp/key.pem' >> /usr/local/bin/start-web && \
    echo '    fi' >> /usr/local/bin/start-web && \
    echo '  fi' >> /usr/local/bin/start-web && \
    echo 'fi' >> /usr/local/bin/start-web && \
    echo '' >> /usr/local/bin/start-web && \
    echo '# Start PHP-FPM' >> /usr/local/bin/start-web && \
    echo 'sudo php-fpm -D' >> /usr/local/bin/start-web && \
    echo '' >> /usr/local/bin/start-web && \
    echo '# Test and start nginx' >> /usr/local/bin/start-web && \
    echo 'sudo nginx -t && sudo nginx -g "daemon off;"' >> /usr/local/bin/start-web && \
    chmod +x /usr/local/bin/start-web

# Fix permissions
RUN mkdir -p /var/cache/nginx && \
    chown -R app:app /etc/nginx /var/www /var/cache/nginx /var/log/nginx /run/nginx /run/php

# Configure bashrc for app user
USER app:app
RUN echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc && \
    echo '/usr/local/bin/show-xve-logo' >> ~/.bashrc && \
    echo 'alias start-web="start-web"' >> ~/.bashrc && \
    echo 'alias nginx-test="sudo nginx -t"' >> ~/.bashrc && \
    echo 'alias nginx-reload="sudo nginx -s reload"' >> ~/.bashrc && \
    echo 'alias nginx-stop="sudo nginx -s quit"' >> ~/.bashrc && \
    echo 'alias logs="sudo tail -f /var/log/nginx/access.log"' >> ~/.bashrc && \
    echo 'alias error-logs="sudo tail -f /var/log/nginx/error.log"' >> ~/.bashrc && \
    echo 'echo "XVE Development Environment"' >> ~/.bashrc && \
    echo 'echo "Run: start-web (to start services)"' >> ~/.bashrc && \
    echo 'echo "URLs: http://localhost | https://localhost"' >> ~/.bashrc

WORKDIR /var/www/html

EXPOSE 80 443

# Default command for WSL
CMD ["/usr/local/bin/start-web"]