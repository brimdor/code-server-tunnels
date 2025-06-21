#!/bin/bash
set -e

export PATH="/home/coder/.local/bin:${PATH}"

setup_zshrc() {
    if [ ! -f /home/coder/.zshrc ]; then
        touch /home/coder/.zshrc
    fi
    if ! grep -qxF 'export PATH="/home/coder/.local/bin:${PATH}"' /home/coder/.zshrc; then
        echo 'export PATH="/home/coder/.local/bin:${PATH}"' >> /home/coder/.zshrc
    fi
}

setup_local_bin() {
    if [ ! -d /home/coder/.local/bin ]; then
        mkdir -p /home/coder/.local/bin
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
    else
        echo "VS Code CLI is up to date (version ${installed_version})."
    fi
}

setup_ssh() {
    if [ "${PRIVATE_RSA}" = "true" ] || [ "${PRIVATE_ED}" = "true" ]; then
        if [ ! -d /home/coder/.ssh ]; then
            mkdir -p /home/coder/.ssh
            chmod 700 /home/coder/.ssh
        fi
        if [ "${PRIVATE_RSA}" = "true" ]; then
            if [ ! -f /home/coder/.ssh/id_rsa ]; then
                ssh-keygen -t rsa -b 4096 -f /home/coder/.ssh/id_rsa -N ""
                chmod 600 /home/coder/.ssh/id_rsa
                chmod 644 /home/coder/.ssh/id_rsa.pub
                echo "********* Generated new RSA SSH keypair *********"
                echo "Public Key: $(cat /home/coder/.ssh/id_rsa.pub)"
                echo "*************************************************"
                echo ""
            fi
        fi
        if [ "${PRIVATE_ED}" = "true" ]; then
            if [ ! -f /home/coder/.ssh/id_ed25519 ]; then
                ssh-keygen -t ed25519 -f /home/coder/.ssh/id_ed25519 -N ""
                chmod 600 /home/coder/.ssh/id_ed25519
                chmod 644 /home/coder/.ssh/id_ed25519.pub
                echo "********* Generated new ED25519 SSH keypair *********"
                echo "Public Key: $(cat /home/coder/.ssh/id_ed25519.pub)"
                echo "*****************************************************"
                echo ""
            fi
        fi
    else
        echo "No SSH key generation requested. Skipping SSH key setup."
    fi
    
    if [ -n "${SSH_PRIVATE}" ] && [ -n "${SSH_PUBLIC}" ]; then
        if [ -f /home/coder/.ssh/public_key ] && [ "$(cat /home/coder/.ssh/public_key)" = "${SSH_PUBLIC}" ]; then
            echo "SSH public key already exists and matches the provided value. Skipping injection."
            return
        elif [ ! -d /home/coder/.ssh ]; then
            echo "********* Creating .ssh directory *********"
            mkdir -p /home/coder/.ssh
            chmod 700 /home/coder/.ssh
        fi

        echo "${SSH_PRIVATE}" > /home/coder/.ssh/private_key
        echo "${SSH_PUBLIC}" > /home/coder/.ssh/public_key
        chmod 600 /home/coder/.ssh/private_key
        chmod 644 /home/coder/.ssh/public_key
        echo "********* SSH Key Injected Successfully *********"
        cat /home/coder/.ssh/public_key
        echo "*************************************************"
        return
    fi
}

setup_git_config() {
    if [ -n "${GITHUB_USERNAME}" ]; then
        git config --global user.name "${GITHUB_USERNAME}"
    fi
    if [ -n "${GITHUB_EMAIL}" ]; then
        git config --global user.email "${GITHUB_EMAIL}"
    fi
}

setup_chezmoi() {
    if [ -z "${CHEZMOI_REPO}" ] || [ -z "${CHEZMOI_BRANCH}" ]; then
        echo "CHEZMOI_REPO and CHEZMOI_BRANCH must be set for chezmoi setup."
        return 1
    fi
    if [ -n "${CHEZMOI_REPO}" ]; then
        echo "*** Setting up Chezmoi with repository ${CHEZMOI_REPO} on branch ${CHEZMOI_BRANCH}."
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /home/coder/.local/bin
        echo "*** Chezmoi Successfully Installed."
        chezmoi init --branch "$CHEZMOI_BRANCH" --apply "$CHEZMOI_REPO"
        echo "*** Chezmoi initialized with repository ${CHEZMOI_REPO} on branch ${CHEZMOI_BRANCH}."
    fi
}

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
        /home/coder/.local/bin/code tunnel user login --provider "${PROVIDER}"
        touch /home/coder/check && echo ${TUNNEL_NAME} > /home/coder/check
    else
        echo "Tunnel already exists."
    fi

    /home/coder/.local/bin/code tunnel --accept-server-license-terms --name "${TUNNEL_NAME}"
}

setup_zshrc
setup_local_bin
setup_vscode_cli
setup_ssh
setup_git_config
setup_chezmoi
start_tunnel