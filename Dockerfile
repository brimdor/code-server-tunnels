FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    sudo \
    zsh \
    file \
    openssh-client \
    xz-utils \
    build-essential \
    procps \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh coder \
  && echo "coder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER coder

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    && chown -R coder:coder /home/linuxbrew/.linuxbrew \
    && echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/coder/.zshrc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0555 /usr/local/bin/entrypoint.sh

WORKDIR /home/coder

CMD ["/usr/local/bin/entrypoint.sh"]