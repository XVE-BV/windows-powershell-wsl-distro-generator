FROM alpine:latest
LABEL maintainer="jonas@xve.be"

# 1) Build-time user args
ARG USER_NAME=xve
ARG USER_UID=1000
ARG USER_GID=1000

# 2) Install core prerequisites (incl. pass, gpg, curl, ca-certs, etc.)
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

# 3) Download Docker credential-pass helper
ARG HELPER_VER=v0.9.3
RUN curl -fsSL \
      https://github.com/docker/docker-credential-helpers/releases/download/${HELPER_VER}/docker-credential-pass-${HELPER_VER}.linux-amd64 \
      -o /usr/local/bin/docker-credential-pass \
 && chmod +x /usr/local/bin/docker-credential-pass

# 4) Clone Powerlevel10k prompt
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/powerlevel10k

# 5) Download the WSL2 SSH-Agent proxy (mame/wsl2-ssh-agent)
ARG WSL_AGENT_VER=v0.4.0
RUN curl -fsSL \
      https://github.com/mame/wsl2-ssh-agent/releases/download/${WSL_AGENT_VER}/wsl2-ssh-agent-linux-amd64 \
      -o /usr/local/bin/wsl2-ssh-agent \
 && chmod +x /usr/local/bin/wsl2-ssh-agent

# 6) Create non-root user & wheel group
RUN addgroup -g "${USER_GID}" "${USER_NAME}" \
 && adduser -D -u "${USER_UID}" -G "${USER_NAME}" -s /bin/zsh "${USER_NAME}" \
 && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && addgroup "${USER_NAME}" wheel

# 7) Prepare /apps and ~/bin for helper scripts
RUN mkdir -p /apps /home/${USER_NAME}/bin

# 8) Copy GPG/pass setup script into ~/bin
COPY scripts/setup-gpg-pass.sh /home/${USER_NAME}/bin/setup-gpg-pass.sh
RUN chmod +x /home/${USER_NAME}/bin/setup-gpg-pass.sh

# 9) Install skeleton Zsh configs
COPY scripts/skel_zshrc /etc/skel/.zshrc
COPY scripts/p10k.zsh   /etc/skel/.p10k.zsh
RUN dos2unix /etc/skel/.zshrc /etc/skel/.p10k.zsh \
 && cp /etc/skel/.zshrc /home/${USER_NAME}/.zshrc \
 && cp /etc/skel/.p10k.zsh /home/${USER_NAME}/.p10k.zsh

# 10) Inject SSH-Agent proxy startup into .zshrc
RUN printf '\n# Start Windows SSH-Agent proxy\nexport SSH_AUTH_SOCK=/tmp/ssh-agent.sock\nnohup /usr/local/bin/wsl2-ssh-agent --addr /tmp/ssh-agent.sock --pipe "$(cmd.exe /C "echo %SSH_AUTH_SOCK%" | tr -d "\r\n")" > /dev/null 2>&1 &\n' \
     >> /home/${USER_NAME}/.zshrc

# 11) Configure Docker credential helper
RUN mkdir -p /home/${USER_NAME}/.docker
COPY scripts/docker-config.json /home/${USER_NAME}/.docker/config.json

# 12) Copy WSL config
COPY wsl.conf /etc/wsl.conf

# 13) Final ownership fix & init
RUN chown -R ${USER_UID}:${USER_GID} /opt/powerlevel10k \
 && chown -R ${USER_UID}:${USER_GID} /usr/local/bin/wsl2-ssh-agent /usr/local/bin/docker-credential-pass \
 && chown -R ${USER_UID}:${USER_GID} /apps /home/${USER_NAME}

CMD ["/sbin/init"]
