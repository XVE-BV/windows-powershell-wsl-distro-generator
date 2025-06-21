# syntax=docker/dockerfile:1

## Builder stage: compile PHP extensions and install Composer
FROM php:8.4-fpm-alpine AS builder

# Install build-time dependencies and Composer installer
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        imagemagick-dev icu-dev zlib-dev jpeg-dev libpng-dev libzip-dev postgresql-dev linux-headers \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install \
        intl pcntl gd exif zip mysqli pgsql pdo pdo_mysql pdo_pgsql bcmath opcache \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && echo "xdebug.mode=coverage" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    # Install Imagick from source
    && IMAGICK_VERSION=3.7.0 \
    && curl -fsSL -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/refs/tags/${IMAGICK_VERSION}.tar.gz \
    && mkdir -p /tmp/imagick-src \
    && tar -C /tmp/imagick-src --strip-components=1 -xf /tmp/imagick.tar.gz \
    && cd /tmp/imagick-src \
    && sed -i 's/php_strtolower/zend_str_tolower/g' imagick.c \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo "extension=imagick.so" > /usr/local/etc/php/conf.d/docker-php-ext-imagick.ini

# Clean up build dependencies and temporary files
RUN apk del .build-deps \
    && rm -rf /tmp/*


## Vendor stage: install global Composer packages for caching
FROM builder AS vendor
# Set COMPOSER_HOME to a known directory to capture global packages
ENV COMPOSER_HOME=/composer
# Install Laravel installer globally (cached as long as this RUN line doesn't change)
RUN composer global require laravel/installer --prefer-dist --no-dev --optimize-autoloader


## Final stage: runtime image
FROM php:8.4-fpm-alpine
LABEL maintainer="XVE Development Distribution"

ARG APP_ID=1000

# Copy compiled PHP extensions and configurations
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Copy global Composer packages (including Laravel installer)
COPY --from=vendor /composer /composer
# Ensure global composer bin is in PATH
ENV PATH="/composer/vendor/bin:$PATH"

# Install runtime-only packages and tools
RUN apk add --no-cache \
        libpng jpeg libzip zip libpq icu imagemagick \
        bash curl git sudo openssl nss-tools sqlite nginx \
    && addgroup -g "$APP_ID" app \
    && adduser -G app -u "$APP_ID" -h /var/www -s /bin/bash -S app \
    && echo 'app ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && mkdir -p /etc/nginx/certs /run/nginx /run/php /var/log/nginx /var/www/html

# Generate a self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/certs/nginx.key \
        -out    /etc/nginx/certs/nginx.crt \
        -subj   "/C=US/ST=Local/L=Local/O=XVE/CN=localhost"

# Copy application code and auxiliary files
COPY . /var/www/html
COPY scripts/show-xve-logo.sh /usr/local/bin/show-xve-logo
COPY conf/nginx.wsl.conf      /etc/nginx/nginx.conf
COPY compose.yml         /var/www/html/compose.yml

# Set permissions and switch to non-root user
RUN chmod +x /usr/local/bin/show-xve-logo \
    && chown -R app:app /var/www /etc/nginx /run/nginx /run/php

USER app
WORKDIR /var/www/html

EXPOSE 80 443
CMD ["/usr/local/bin/start-web"]
