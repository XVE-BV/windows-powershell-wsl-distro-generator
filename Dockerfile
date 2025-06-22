FROM alpine:latest
LABEL maintainer="jonas@xve.be"

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 1) Install core prerequisites
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli bash \
      ncurses ncurses-terminfo dos2unix socat wget curl \
      python3 py3-pip python3-dev py3-setuptools \
      # GitFourchette Python deps
      py3-pygit2 py3-pygments py3-pyqt6 \
      # Qt6 SVG support
      qt6-qtsvg \
      # build tools for any native modules
      build-base \
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

# 5) Install skeleton Zsh configs
USER root
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh   /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh

# 6) Install GitFourchette and set update alias
USER ${USER_NAME}
ENV PATH="/home/${USER_NAME}/.local/bin:$PATH"
RUN pip3 install --user gitfourchette \
 && echo "# alias to update GitFourchette" >> /home/${USER_NAME}/.zshrc \
 && echo "alias gf-update='pip3 install --user --upgrade gitfourchette'" >> /home/${USER_NAME}/.zshrc

# 7) Configure Docker to _not_ use a credential helper (fallback to plaintext)
USER root
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json

# 8) Copy WSL config
COPY wsl.conf /etc/wsl.conf

# 9) Final ownership fix
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k /apps /home/${USER_NAME}

# 10) Default command
CMD ["/sbin/init"]
