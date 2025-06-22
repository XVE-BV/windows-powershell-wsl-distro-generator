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


# Create the user at build-time, so default=xve works immediately
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid "${USER_GID}" "${USER_NAME}" \
 && useradd --create-home \
            --uid "${USER_UID}" \
            --gid "${USER_GID}" \
            --shell /bin/bash \
            "${USER_NAME}" \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y sudo \
 && usermod -aG sudo "${USER_NAME}" \
 && rm -rf /var/lib/apt/lists/*

# Copy your init script & wsl.conf
COPY wsl-init.sh /usr/local/bin/wsl-init.sh
RUN chmod 755 /usr/local/bin/wsl-init.sh
COPY wsl.conf /etc/wsl.conf

CMD ["/lib/systemd/systemd"]
