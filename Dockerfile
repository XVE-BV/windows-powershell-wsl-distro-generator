# Use the latest Alpine base image
FROM alpine:latest

LABEL maintainer="jonas@xve.be"

# Install Docker CLI and Git
RUN apk update \
 && apk add --no-cache \
      shadow \
      sudo \
      openrc \
      git \
      docker-cli \
 && rm -rf /var/cache/apk/*

# Copy and enable your init script
COPY wsl-init.sh /usr/local/bin/wsl-init.sh
RUN chmod 755 /usr/local/bin/wsl-init.sh

# Copy in WSL config
COPY wsl.conf /etc/wsl.conf

CMD ["/usr/sbin/init"]
