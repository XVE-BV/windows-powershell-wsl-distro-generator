FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Build-time user args
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 2) Install core prerequisites (incl. socat, curl, pass, gpg, CA certs)
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
      pass \
      gnupg \
      ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

# 3) Download the Docker credential-pass helper
ARG HELPER_VER=v0.9.3
RUN curl -fsSL \
      https://github.com/docker/docker-credential-helpers/releases/download/${HELPER_VER}/docker-credential-pass-${HELPER_VER}-linux-amd64 \
      -o /usr/local/bin/docker-credential-pass \
 && chmod +x /usr/local/bin/docker-credential-pass

# 4) Clone Powerlevel10k prompt
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 5) Clone the WSL SSH-Agent proxy
RUN git clone https://github.com/ubuntu/wsl-ssh-agent-proxy.git /opt/wsl-ssh-agent-proxy

# 6) Create non-root user and wheel group
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 7) Prepare /apps directory
RUN mkdir -p /apps

# 8) Copy GPG/pass setup script into user bin
RUN mkdir -p /home/${USER_NAME}/bin \
 && cp scripts/setup-gpg-pass.sh /home/${USER_NAME}/bin/setup-gpg-pass.sh \
 && chmod +x /home/${USER_NAME}/bin/setup-gpg-pass.sh

# 9) Install skeleton Zsh configs
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh   /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh

# 10) Inject SSH-agent proxy startup into .zshrc
RUN printf '\n# Start Windows SSH-Agent proxy\nexport SSH_AUTH_SOCK=/tmp/ssh-agent.sock\nnohup /opt/wsl-ssh-agent-proxy/ssh-agent-proxy > /dev/null 2>&1 &\n' \
     >> /home/${USER_NAME}/.zshrc

# 11) Configure Docker credential helper
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json

# 12) Copy WSL config
COPY wsl.conf /etc/wsl.conf

# 13) Final ownership fix (single layer) & init
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k \
 && chown -R ${USER_UID}:${USER_GID} /opt/wsl-ssh-agent-proxy \
 && chown -R ${USER_UID}:${USER_GID} /apps \
 && chown -R ${USER_UID}:${USER_GID} /home/${USER_NAME}

CMD ["/sbin/init"]
