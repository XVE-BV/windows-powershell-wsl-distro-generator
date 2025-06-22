FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Install prerequisites
RUN apk update && apk add --no-cache \
      zsh \
      shadow \
      sudo \
      git \
      docker-cli \
      docker-credential-helpers \
      ncurses \
      ncurses-terminfo \
      dos2unix \
    && rm -rf /var/cache/apk/*

# 1a) Clone Powerlevel10k
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k \
 && chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k

# 2) Create non-root user
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 3) Prepare /apps
RUN mkdir -p /apps \
 && chown ${USER_UID}:${USER_GID} /apps

# 4) Install shell config and templates
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh    /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && chmod 644 /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh \
 && chown ${USER_UID}:${USER_GID} /home/${USER_NAME}/.zshrc /home/${USER_NAME}/.p10k.zsh

# Create the .docker folder, copy in the config, then fix ownership
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json
RUN chown -R ${USER_UID}:${USER_GID} /home/${USER_NAME}/.docker

# 6) WSL integration config
COPY wsl.conf /etc/wsl.conf

# 7) Boot via OpenRC
CMD ["/sbin/init"]
