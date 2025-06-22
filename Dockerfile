FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends -qq \
    -o=Dpkg::Options::=--force-confdef \
    -o=Dpkg::Options::=--force-confold \
    apparmor \
    bind9-host \
    build-essential \
    ca-certificates \
    cgroupfs-mount \
    containerd \
    coreutils \
    criu \
    curl \
    docker-compose \
    docker.io \
    gawk \
    gettext-base \
    git \
    gpg \
    gnupg \
    hostname \
    iproute2 \
    iproute2 \
    iptables \
    iputils-ping \
    libatm1 \
    libbpf1 \
    libc-l10n \
    libevent-core-2.1-7 \
    libintl-perl \
    libintl-xs-perl \
    libip6tc2 \
    libmnl0 \
    libmodule-find-perl \
    libnet1 \
    libnetfilter-conntrack3 \
    libnfnetlink0 \
    libnftables1 \
    libnftnl11 \
    libnl-3-200 \
    libproc-processtable-perl \
    libprotobuf-c1 \
    libprotobuf32 \
    libsort-naturally-perl \
    libssh-4 \
    libterm-readkey-perl \
    libutempter0 \
    libvirt-clients \
    libvirt-l10n \
    libvirt0 \
    libxtables12 \
    libyajl2 \
    locales \
    lsb-release \
    needrestart \
    netcat-openbsd \
    nftables \
    openssh-client \
    procps \
    python3 \
    python3-attr \
    python3-docker \
    python3-dockerpty \
    python3-docopt \
    python3-dotenv \
    python3-json-pointer \
    python3-jsonschema \
    python3-pip \
    python3-protobuf \
    python3-pyrsistent \
    python3-rfc3987 \
    python3-texttable \
    python3-uritemplate \
    python3-webcolors \
    python3-websocket \
    runc \
    sensible-utils \
    software-properties-common \
    sudo \
    tini \
    tmux \
    unzip \
    wget \
    zsh \
  && rm -rf /var/lib/apt/lists/*

RUN DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq needrestart > /dev/null

RUN useradd -m -s /bin/zsh coder \
  && echo "coder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER coder
WORKDIR /home/coder

COPY --chown=coder:coder entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0555 /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]