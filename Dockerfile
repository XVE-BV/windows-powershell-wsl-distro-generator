FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Install prerequisites (zsh, git, sudo, docker-cli, ncurses, dos2unix)
RUN apk update && apk add --no-cache \
      zsh \
      shadow \
      sudo \
      git \
      docker-cli \
      ncurses \
      ncurses-terminfo \
      dos2unix \
    && rm -rf /var/cache/apk/*

# 2) Install Powerlevel10k theme globally
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 3) Create the non-root user at build time
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 4) Prepare /apps as the working directory
RUN mkdir -p /apps \
 && chown ${USER_UID}:${USER_GID} /apps \
 && chmod 755 /apps

# 5) Populate both /etc/skel and the actual home with .zshrc, fixing CRLF → LF
COPY scripts/skel_zshrc /etc/skel/.zshrc
RUN dos2unix /etc/skel/.zshrc \
 && chmod 644 /etc/skel/.zshrc
RUN install -o ${USER_NAME} -g ${USER_NAME} -m 644 /etc/skel/.zshrc /home/${USER_NAME}/.zshrc

# 6) Copy in WSL config (automount & default user)
COPY wsl.conf /etc/wsl.conf

# 7) Launch OpenRC’s init so that services and chsh work
CMD ["/sbin/init"]
