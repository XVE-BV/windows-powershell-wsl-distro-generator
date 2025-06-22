FROM alpine:latest

LABEL maintainer="jonas@xve.be"

# 1) Install prerequisites
RUN apk update \
 && apk add --no-cache \
      shadow \
      sudo \
      openrc \
      git \
      docker-cli \
 && rm -rf /var/cache/apk/*

# 2) Create the non-root user at build time
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/sh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 3) Copy in your WSL config (no boot hook unless you re-add wsl-init.sh)
COPY wsl.conf /etc/wsl.conf

# 4) Launch OpenRC’s init
CMD ["/sbin/init"]
