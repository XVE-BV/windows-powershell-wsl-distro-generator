FROM alpine:latest
LABEL maintainer="jonas@xve.be"

ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# Install packages
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli bash \
      ncurses ncurses-terminfo dos2unix socat wget curl \
      openssh docker-compose net-tools \
    && rm -rf /var/cache/apk/*

# Clone Powerlevel10k
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# Create docker group (if it doesn't exist) and user, then add to groups
RUN (addgroup docker 2>/dev/null || true) \
 && addgroup "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel \
 && addgroup "${USER_NAME}" docker

# Create directories
RUN mkdir -p /apps /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt \
 && mkdir -p /home/${USER_NAME}/.docker

# Copy and process configuration files
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh /etc/skel/.p10k.zsh
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json
COPY wsl.conf /etc/wsl.conf
COPY nginx-proxy-manager-compose.yml /opt/nginx-proxy-manager/docker-compose.yml
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/auto-setup.sh /usr/local/bin/auto-setup.sh

# Process all files and set permissions
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh /entrypoint.sh /usr/local/bin/auto-setup.sh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh \
 && chmod +x /entrypoint.sh /usr/local/bin/auto-setup.sh

# Set ownership
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k /apps /home/${USER_NAME} /opt/nginx-proxy-manager

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]