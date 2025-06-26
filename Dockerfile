FROM alpine:latest
LABEL maintainer="jonas@xve.be"

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 1) Install core prerequisites
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli bash \
      ncurses ncurses-terminfo dos2unix socat wget curl \
      openssh jq \
    && rm -rf /var/cache/apk/*

# 2) (Optional) Clone Powerlevel10k prompt
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 3) Create non-root user
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 4) Prepare /apps directory
RUN mkdir -p /apps

# 5) Install skeleton Zsh configs
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh   /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh

# 6) Configure Docker to _not_ use a credential helper (fallback to plaintext)
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json

# 7) Copy WSL config
COPY wsl.conf /etc/wsl.conf

# 8) Install patch management system
COPY scripts/patch-manager.sh /usr/local/bin/patch-manager
COPY scripts/selfupdate /usr/local/bin/selfupdate
RUN mkdir -p /opt/xve-patches/available
RUN chmod +x /usr/local/bin/patch-manager /usr/local/bin/selfupdate \
 && mkdir -p /opt/xve-patches/backups \
 && echo '{"applied_patches": [], "last_update": null, "version": "1.0"}' > /opt/xve-patches/applied_patches.json

# 9) Final ownership fix & init
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k \
 && chown -R ${USER_UID}:${USER_GID} /apps /home/${USER_NAME} /opt/xve-patches

CMD ["/sbin/init"]
