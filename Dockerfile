# Multi-stage Dockerfile: Build GitFourchette in Ubuntu, then copy to Alpine with glibc

# ---------------------
# Stage 1: Builder (Ubuntu)
# ---------------------
FROM ubuntu:22.04 AS builder

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# Install Python, Qt runtime libs, and build dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev build-essential git \
      libpython3-dev libgit2-dev \
      libqt6core6 libqt6gui6 libqt6widgets6 \
 && rm -rf /var/lib/apt/lists/*

# Create a virtual environment for GitFourchette and install dependencies
WORKDIR /opt/gitfourchette
RUN python3 -m venv .venv \
 && . .venv/bin/activate \
 && pip install --upgrade pip setuptools wheel PyQt6 PyQt6-Svg git+https://github.com/jorio/gitfourchette.git \
 && ls -l .venv/bin/gitfourchette

# ---------------------
# Stage 2: Runtime (Alpine with glibc)
# ---------------------
FROM frolvlad/alpine-glibc:3.18 AS runtime
LABEL maintainer="jonas@xve.be"

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 1) Install core prerequisites and Qt6 runtime support
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli bash \
      ncurses ncurses-terminfo dos2unix socat wget curl \
      python3 py3-pip libstdc++ libgcc \
      qt6-qtbase qt6-qtsvg \
    && rm -rf /var/cache/apk/*

# 2) Clone Powerlevel10k prompt
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 3) Create non-root user matching host privileges
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 4) Prepare application directory
RUN mkdir -p /apps

# 5) Copy skeleton shell configs and Docker config directory
USER root
RUN mkdir -p /home/${USER_NAME}/.docker \
 && chown ${USER_UID}:${USER_GID} /home/${USER_NAME}/.docker
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json
COPY wsl.conf /etc/wsl.conf

# 6) Copy pre-built GitFourchette virtualenv from builder and fix ownership
COPY --from=builder /opt/gitfourchette/.venv /home/${USER_NAME}/.venv
RUN chown -R ${USER_UID}:${USER_GID} /home/${USER_NAME}

# 7) Configure virtualenv activation and update alias in shell config
USER ${USER_NAME}
ENV VIRTUAL_ENV="/home/${USER_NAME}/.venv"
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"
RUN echo "# Activate GitFourchette environment" >> /home/${USER_NAME}/.zshrc \
 && echo "export VIRTUAL_ENV=\"${VIRTUAL_ENV}\"" >> /home/${USER_NAME}/.zshrc \
 && echo "export PATH=\"${VIRTUAL_ENV}/bin:$PATH\"" >> /home/${USER_NAME}/.zshrc \
 && echo "# Alias to update GitFourchette" >> /home/${USER_NAME}/.zshrc \
 && echo "alias gf-update='/home/${USER_NAME}/.venv/bin/pip install --upgrade git+https://github.com/jorio/gitfourchette.git'" >> /home/${USER_NAME}/.zshrc

# 8) Final ownership fix for configs and application dir
USER root
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k /apps /home/${USER_NAME}

# 9) Default command: start an interactive Zsh shell
USER ${USER_NAME}
CMD ["/bin/zsh"]
