# Multi-stage Dockerfile: Build GitFourchette in Ubuntu, then copy to Alpine

# ---------------------
# Stage 1: Builder (Ubuntu)
# ---------------------
FROM ubuntu:24.04 AS builder

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# Install Python and build deps
RUN apt update && apt install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev build-essential git qt6-svg-dev libqt6svg6 \
      libpython3-dev libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a venv for GitFourchette
WORKDIR /opt/gitfourchette
RUN python3 -m venv .venv \
 && . .venv/bin/activate \
 && pip install --upgrade pip setuptools wheel \
 && pip install gitfourchette

# ---------------------
# Stage 2: Runtime (Alpine)
# ---------------------
FROM alpine:latest
LABEL maintainer="jonas@xve.be"

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 1) Install core prerequisites
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli bash \
      ncurses ncurses-terminfo dos2unix socat wget curl \
      python3 py3-pip libstdc++ libgcc \
      # Qt6 runtime support
      qt6-qtsvg \
    && rm -rf /var/cache/apk/*

# 2) Clone Powerlevel10k prompt
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 3) Create non-root user
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 4) Prepare /apps directory
RUN mkdir -p /apps

# 5) Install skeleton Zsh configs and Docker config directory
USER root
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh   /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json
COPY wsl.conf /etc/wsl.conf

# 6) Copy GitFourchette venv from builder
COPY --from=builder /opt/gitfourchette/.venv /home/${USER_NAME}/.venv

# 7) Setup environment and alias
USER ${USER_NAME}
ENV PATH="/home/${USER_NAME}/.venv/bin:$PATH"
RUN echo "# GitFourchette venv activation" >> /home/${USER_NAME}/.zshrc \
 && echo "source ~/\.venv/bin/activate" >> /home/${USER_NAME}/.zshrc \
 && echo "# alias to update GitFourchette" >> /home/${USER_NAME}/.zshrc \
 && echo "alias gf-update=' \"~/\.venv/bin/pip\" install --upgrade gitfourchette'" >> /home/${USER_NAME}/.zshrc

# 8) Final ownership fix
USER root
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k /apps /home/${USER_NAME}

# 9) Default command
CMD ["/sbin/init"]
