# Use the latest Alpine base image
FROM alpine:latest

LABEL maintainer="jonas@xve.be"

# Install Docker CLI and Git
RUN apk update \
 && apk add --no-cache \
      docker-cli \
      git \
 && rm -rf /var/cache/apk/*

# Configure Docker CLI to use the host Docker daemon socket
ENV DOCKER_HOST=unix:///var/run/docker.sock

# Create a non-root user (optional)
ARG USER=developer
ARG UID=1000
ARG GID=1000
RUN addgroup -g ${GID} ${USER} \
 && adduser -D -u ${UID} -G ${USER} ${USER}

USER ${USER}
WORKDIR /home/${USER}

# Default to an interactive shell
CMD ["sh"]