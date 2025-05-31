#!/bin/bash
set -e

setup_permissions() {
    chmod g+w /home/coder
    chgrp -R 0 /home/coder
    chmod -R g=u /home/coder
    if [ ! -d /home/coder ]; then
        mkdir -p /home/coder
        chown coder:coder /home/coder
    fi
    chown -R coder:coder /home/coder
}

setup_zshrc() {
    if [ ! -f /home/coder/.zshrc ]; then
        touch /home/coder/.zshrc
        chown coder:coder /home/coder/.zshrc
    fi
    if ! grep -qxF 'export PATH="/home/coder/.local/bin:${PATH}"' /home/coder/.zshrc; then
        echo 'export PATH="/home/coder/.local/bin:${PATH}"' >> /home/coder/.zshrc
    fi
}

setup_local_bin() {
    if [ ! -d /home/coder/.local/bin ]; then
        mkdir -p /home/coder/.local/bin
        chown -R coder:coder /home/coder/.local
    fi
    if [ ! -f /home/coder/.local/bin/code ]; then
        curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" \
            -o /home/coder/vscode-cli.tar.gz
        tar -xzf /home/coder/vscode-cli.tar.gz -C /home/coder
        rm /home/coder/vscode-cli.tar.gz
        mv /home/coder/code /home/coder/.local/bin/code
        chmod +x /home/coder/.local/bin/code
        chown coder:coder /home/coder/.local/bin/code
    fi
}

########## CUSTOMIZATIONS ##########

setup_ssh() {
    if [ "${PRIVATE_KEY}" = "true" ]; then
        if [ ! -d /home/coder/.ssh ]; then
            mkdir -p /home/coder/.ssh
            chown coder:coder /home/coder/.ssh
            chmod 700 /home/coder/.ssh
        fi
        if [ ! -f /home/coder/.ssh/id_rsa ]; then
            su coder -c "ssh-keygen -t rsa -b 4096 -f /home/coder/.ssh/id_rsa -N ''"
            chown coder:coder /home/coder/.ssh/id_rsa
            chown coder:coder /home/coder/.ssh/id_rsa.pub
            chmod 600 /home/coder/.ssh/id_rsa
            chmod 644 /home/coder/.ssh/id_rsa.pub
            echo "********* SSH Key Generated Successfully **********"
            cat /home/coder/.ssh/id_rsa.pub
            echo "***************************************************"
        fi
    fi

    if [ -n "${SSH_PRIVATE}" ] && [ -n "${SSH_PUBLIC}" ]; then
        if [ ! -d /home/coder/.ssh ]; then
            mkdir -p /home/coder/.ssh
            chown coder:coder /home/coder/.ssh
            chmod 700 /home/coder/.ssh
        fi
        echo "${SSH_PRIVATE}" > /home/coder/.ssh/id_rsa
        echo "${SSH_PUBLIC}" > /home/coder/.ssh/id_rsa.pub
        chown coder:coder /home/coder/.ssh/id_rsa /home/coder/.ssh/id_rsa.pub
        chmod 600 /home/coder/.ssh/id_rsa
        chmod 644 /home/coder/.ssh/id_rsa.pub
        echo "********* SSH Key Injected Successfully **********"
        cat /home/coder/.ssh/id_rsa.pub
        echo "*************************************************"
    fi
}

setup_docker() {
    if [ -n "${DOCKER_HOST}" ]; then
        docker_host_ip=$(echo "${DOCKER_HOST}" | sed -n 's/.*@\(.*\)/\1/p' | sed 's#/.*##')
        echo "Setting up Docker with host ${docker_host_ip}"
        if ! command -v docker &>/dev/null; then
            echo "Docker CLI not found. Installing docker as coder..."
            su coder -c 'sudo apt-get update'
            su coder -c 'sudo apt-get install -y docker.io'
        else
            echo "Docker CLI is available."
        fi
        if ! getent group docker >/dev/null; then
            groupadd docker
        fi
        if ! id -nG coder | grep -qw docker; then
            usermod -aG docker coder
            echo "Added coder to docker group"
        fi
        if [ "${DOCKER_COMPOSE}" = "true" ]; then
            if ! command -v docker-compose &>/dev/null; then
                su coder -c 'sudo apt-get update'
                su coder -c 'sudo apt-get install -y ca-certificates curl gnupg lsb-release'
                su coder -c 'sudo mkdir -p /etc/apt/keyrings'
                su coder -c 'curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
                su coder -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
                su coder -c 'sudo apt-get update'
                su coder -c 'sudo apt-get install -y docker-compose-plugin'
            else
                echo "Docker Compose is already installed."
            fi
        else
            echo "Skipping Docker Compose Install."
        fi
        # if [ -n "${docker_host_ip}" ]; then
        #     if ! grep -q "${docker_host_ip}" /home/coder/.ssh/known_hosts 2>/dev/null; then
        #         if [ ! -d /home/coder/.ssh ]; then
        #             mkdir -p /home/coder/.ssh
        #             chown coder:coder /home/coder/.ssh
        #             chmod 700 /home/coder/.ssh
        #         fi
        #         ssh-keyscan -H "${docker_host_ip}" >> /home/coder/.ssh/known_hosts 2>/dev/null
        #         chown coder:coder /home/coder/.ssh/known_hosts
        #         chmod 644 /home/coder/.ssh/known_hosts
        #         echo "Added ${docker_host_ip} to known_hosts"
        #     fi
        # fi
    fi
}

setup_git_config() {
    if [ -n "${GIT_USER_NAME}" ]; then
        su coder -c "git config --global user.name '${GIT_USER_NAME}'"
    fi
    if [ -n "${GIT_USER_EMAIL}" ]; then
        su coder -c "git config --global user.email '${GIT_USER_EMAIL}'"
    fi
}

####################################


start_tunnel() {
    local TUNNEL_NAME="${TUNNEL_NAME:-vscode-tunnel}"
    local PROVIDER="${PROVIDER:-github}"
    export PATH="/home/coder/.local/bin:${PATH}"

    if [ -f /home/coder/check ]; then
        local OLD_TUNNEL_NAME=$(cat /home/coder/check)
        if [ "${OLD_TUNNEL_NAME}" != "${TUNNEL_NAME}" ]; then
            rm -f /home/coder/.vscode/cli/token.json /home/coder/.vscode/cli/code_tunnel.json
            echo "Removed old tunnel configuration."
        fi
    fi

    if [ ! -f /home/coder/.vscode/cli/token.json ] || [ ! -f /home/coder/.vscode/cli/code_tunnel.json ]; then
        su coder -c "export HOME=/home/coder; /home/coder/.local/bin/code tunnel user login --provider '${PROVIDER}'"
        su coder -c "touch /home/coder/check && echo ${TUNNEL_NAME} > /home/coder/check"
        chown coder:coder /home/coder/check
    else
        echo "Tunnel already exists."
    fi

    su coder -c "export HOME=/home/coder; /home/coder/.local/bin/code tunnel --accept-server-license-terms --name '${TUNNEL_NAME}'"
}

setup_permissions
setup_zshrc
setup_local_bin
#### CUSTOMIZATIONS ####
setup_ssh
setup_docker
setup_git_config
########################
start_tunnel