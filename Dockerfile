FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Install prerequisites (zsh, git, sudo, docker-cli, ncurses-utils for tput, etc.)
RUN apk update \
 && apk add --no-cache \
      zsh \
      shadow \
      sudo \
      git \
      docker-cli \
      ncurses \
      ncurses-terminfo \
 && rm -rf /var/cache/apk/*

# 2) Create the non-root user at build time
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 3) Prepare /apps as the working directory
RUN mkdir -p /apps \
 && chown ${USER_UID}:${USER_GID} /apps \
 && chmod 755 /apps

# 4) Populate /etc/skel/.zshrc so every new home gets the same zsh setup
COPY scripts/skel_zshrc /etc/skel/.zshrc
RUN chmod 644 /etc/skel/.zshrc

# 5) Set default user for WSL and automount options
COPY wsl.conf /etc/wsl.conf

# 6) Launch OpenRC’s init so that "chsh" and other services work
CMD ["/sbin/init"]
