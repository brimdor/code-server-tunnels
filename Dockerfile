FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    sudo \
    zsh \
    openssh-client \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh coder \
  && echo "coder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0555 /usr/local/bin/entrypoint.sh

WORKDIR /home/coder

CMD ["/usr/local/bin/entrypoint.sh"]