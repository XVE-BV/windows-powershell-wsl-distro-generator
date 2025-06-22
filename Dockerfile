FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Install prerequisites (including dos2unix)
RUN apk update && apk add --no-cache \
      zsh shadow sudo git docker-cli \
      ncurses ncurses-terminfo dos2unix \
    && rm -rf /var/cache/apk/*

# 2) Create user
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 3) Prepare /apps
RUN mkdir -p /apps \
 && chown ${USER_UID}:${USER_GID} /apps

# 4) Copy and normalize skeleton .zshrc
COPY scripts/skel_zshrc /etc/skel/.zshrc
RUN dos2unix /etc/skel/.zshrc \
 && chmod 644 /etc/skel/.zshrc

# 5) Copy your custom p10k.zsh into /etc/skel and normalize
COPY scripts/p10k.zsh /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.p10k.zsh \
 && chmod 644 /etc/skel/.p10k.zsh

# (Optional) Ensure the home dir gets these files
#    Only needed if the home was mkdir’d earlier; otherwise /etc/skel will apply automatically.
RUN cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh \
 && chown ${USER_UID}:${USER_GID} /home/${USER_NAME}/.zshrc /home/${USER_NAME}/.p10k.zsh

# 6) WSL config
COPY wsl.conf /etc/wsl.conf

# 7) Boot init
CMD ["/sbin/init"]
