FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Build-time user args
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 2) Install prerequisites (including socat, wget)
RUN apk update && apk add --no-cache \
      zsh \
      shadow \
      sudo \
      git \
      docker-cli \
      ncurses \
      ncurses-terminfo \
      dos2unix \
      socat \
      wget \
      curl \
      ca-certificates \
      && update-ca-certificates \
    && rm -rf /var/cache/apk/*

# 2a) Download the Docker credential helper (secretservice)
ARG HELPER_VER=v0.9.3
RUN curl -fsSL \
      https://github.com/docker/docker-credential-helpers/releases/download/${HELPER_VER}/docker-credential-secretservice-linux-amd64 \
      -o /usr/local/bin/docker-credential-secretservice \
 && chmod +x /usr/local/bin/docker-credential-secretservice

# 3) Clone Powerlevel10k
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 4) Clone the WSL SSH-Agent proxy
RUN git clone https://github.com/ubuntu/wsl-ssh-agent-proxy.git /opt/wsl-ssh-agent-proxy

# 5) Create non-root user
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 6) Prepare /apps
RUN mkdir -p /apps

# 7) Install shell configs
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh    /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh

# 8) Inject SSH-agent proxy startup
RUN cat <<'EOF' >> /home/${USER_NAME}/.zshrc
# Start Windows SSH-Agent proxy
export SSH_AUTH_SOCK=/tmp/ssh-agent.sock
nohup /opt/wsl-ssh-agent-proxy/ssh-agent-proxy > /dev/null 2>&1 &
EOF

# 9) Configure Docker creds
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json

# 10) WSL config
COPY wsl.conf /etc/wsl.conf

# 11) Final ownership fix and init
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k \
 && chown -R ${USER_UID}:${USER_GID} /opt/wsl-ssh-agent-proxy \
 && chown -R ${USER_UID}:${USER_GID} /apps \
 && chown -R ${USER_UID}:${USER_GID} /home/${USER_NAME}

CMD ["/sbin/init"]
