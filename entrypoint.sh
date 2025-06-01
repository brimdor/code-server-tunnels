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
}

setup_vscode_cli() {
    redirect_url=$(curl -fsSLI "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" | grep -i '^location:' | awk '{print $2}' | tr -d '\r\n')
    latest_version=$(echo "$redirect_url" | sed -E 's#.*/stable/([^/]+)/.*#\1#')
    installed_version=""
    if [ -f /home/coder/.local/bin/code ]; then
        installed_version=$(/home/coder/.local/bin/code --version | grep -oE '[a-f0-9]{40}' | head -n1)
    fi

    if [ ! -f /home/coder/.local/bin/code ] || [ "$installed_version" != "$latest_version" ]; then
        echo "Updating VS Code CLI: installed=${installed_version:-none}, latest=${latest_version}"
        curl -fsSL "$redirect_url" -o /home/coder/vscode-cli.tar.gz
        tar -xzf /home/coder/vscode-cli.tar.gz -C /home/coder
        rm /home/coder/vscode-cli.tar.gz
        mv /home/coder/code /home/coder/.local/bin/code
        chmod +x /home/coder/.local/bin/code
        chown coder:coder /home/coder/.local/bin/code
    else
        echo "VS Code CLI is up to date (version ${installed_version})."
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
        echo "Setting up Docker CLI for remote host ${docker_host_ip}"

        # Get the latest docker-<version>.tgz by date (last entry in the list)
        latest_version=$(curl -fsSL https://download.docker.com/linux/static/stable/x86_64/ \
            | grep -oP 'docker-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.tgz)' \
            | sort -V | tail -n1)

        if [ -z "$latest_version" ]; then
            echo "Failed to fetch latest Docker CLI version."
            return 1
        fi

        installed_version=""
        if [ -f /home/coder/.local/bin/docker ]; then
            installed_version=$(/home/coder/.local/bin/docker version --format '{{.Client.Version}}' 2>/dev/null || true)
        fi

        if [ -z "$installed_version" ] || [ "$installed_version" != "$latest_version" ]; then
            echo "Updating Docker CLI: installed=${installed_version:-none}, latest=${latest_version}"
            su coder -c 'mkdir -p /home/coder/.local/bin'
            su coder -c "curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${latest_version}.tgz -o /home/coder/docker-cli.tgz"
            su coder -c "tar -xzf /home/coder/docker-cli.tgz -C /home/coder/.local/bin --strip-components=1 docker/docker"
            su coder -c "rm /home/coder/docker-cli.tgz"
            su coder -c "chmod +x /home/coder/.local/bin/docker"
            echo "Docker CLI v${latest_version} installed."
        else
            echo "Docker CLI is already installed and up to date (version ${installed_version})."
        fi

        if [ -n "${docker_host_ip}" ]; then
            if ! grep -q "${docker_host_ip}" /home/coder/.ssh/known_hosts 2>/dev/null; then
                if [ ! -d /home/coder/.ssh ]; then
                    mkdir -p /home/coder/.ssh
                    chown coder:coder /home/coder/.ssh
                    chmod 700 /home/coder/.ssh
                fi
                ssh-keyscan -H "${docker_host_ip}" >> /home/coder/.ssh/known_hosts 2>/dev/null
                chown coder:coder /home/coder/.ssh/known_hosts
                chmod 644 /home/coder/.ssh/known_hosts
                echo "Added ${docker_host_ip} to known_hosts"
            fi
        fi
    fi
}

setup_docker_compose() {
    if [ "${DOCKER_COMPOSE}" = "true" ]; then
        latest_version=$(curl -fsSL "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
        installed_version=""
        if [ -f /home/coder/.local/bin/docker-compose ]; then
            installed_version=$(/home/coder/.local/bin/docker-compose version --short 2>/dev/null || true)
        fi

        if [ -z "$installed_version" ] || [ "$installed_version" != "$latest_version" ]; then
            echo "Updating Docker Compose: installed=${installed_version:-none}, latest=${latest_version}"
            su coder -c "curl -fsSL \"https://github.com/docker/compose/releases/download/v${latest_version}/docker-compose-linux-x86_64\" -o /home/coder/.local/bin/docker-compose"
            su coder -c "chmod +x /home/coder/.local/bin/docker-compose"
            echo "Docker Compose v${latest_version} installed."
        else
            echo "Docker Compose is up to date (version ${installed_version})."
        fi
    else
        echo "Skipping Docker Compose Install."
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
setup_vscode_cli
#### CUSTOMIZATIONS ####
setup_ssh
setup_docker
setup_docker_compose
setup_git_config
########################
start_tunnel