# CODE SERVER TUNNELS

## Overview

`code-server-tunnels` is a Docker image designed to run VS Code in the browser using the VS Code CLI tunnel feature. It supports SSH key injection, Docker CLI integration, and Git configuration.

---

## Usage

### Running with Docker

```sh
docker run -it \
  -e TUNNEL_NAME=my-tunnel \
  -e PROVIDER={github or microsoft} \
  -e PRIVATE_KEY=true \
  -e SSH_PRIVATE={secret} \
  -e SSH_PUBLIC={secret} \
  -e DOCKER_HOST=ssh://user@host \
  -e DOCKER_COMPOSE=true \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your@email.com" \
  {registry/repository:version}
```

### With Helm or Kubernetes

Set the environment variables in your `values.yaml` or Pod spec under `env:` as shown above.

---

## Environment Variables

| Variable           | Required | Description |
|--------------------|----------|-------------|
| `TUNNEL_NAME`      | No       | Name for the VS Code tunnel. Default: `vscode-tunnel` |
| `PROVIDER`         | No       | Tunnel provider. Default: `github` |
| `PRIVATE_KEY`      | No       | If `true`, auto-generates an SSH key for the `coder` user. |
| `SSH_PRIVATE`      | No       | The private SSH key to inject into `/home/coder/.ssh/id_rsa`. |
| `SSH_PUBLIC`       | No       | The public SSH key to inject into `/home/coder/.ssh/id_rsa.pub`. |
| `DOCKER_HOST`      | No       | Docker host to connect to, e.g. `ssh://user@host`. If set, Docker CLI is installed and the host's SSH key is added to `known_hosts`. |
| `DOCKER_COMPOSE`   | No       | If `true`, installs the newer Docker Compose plugin. |
| `GIT_USER_NAME`    | No       | Sets the global Git user name for the `coder` user. (For Github Repos) |
| `GIT_USER_EMAIL`   | No       | Sets the global Git user email for the `coder` user. (For Github Repos) |

---

## Features

- Automatic VS Code tunnel setup
- SSH key generation or injection
- Docker CLI installation and setup
- Optional Docker Compose plugin installation
- Git global user configuration
- Known hosts management for remote Docker hosts
- Zsh configuration for PATH

---

## Example Helm values.yaml

```yaml
env:
  - name: TUNNEL_NAME
    value: my-tunnel
  - name: PROVIDER
    value: github
  - name: PRIVATE_KEY
    value: "true"
  - name: SSH_PRIVATE
    valueFrom:
      secretKeyRef:
        name: my-ssh-secret
        key: id_rsa
  - name: SSH_PUBLIC
    valueFrom:
      secretKeyRef:
        name: my-ssh-secret
        key: id_rsa.pub
  - name: DOCKER_HOST
    value: ssh://user@host
  - name: DOCKER_COMPOSE
    value: "true"
  - name: GIT_USER_NAME
    value: "Your Name"
  - name: GIT_USER_EMAIL
    value: "your@email.com"
```

---

## Tools

This repository includes helper scripts in the `tools/` directory:

- `tools/build_push.sh`: Prompts for Docker image name, username, and password, then builds and pushes the image to Docker Hub (or any Docker registry).
- `tools/cleanup.sh`: Cleans up your Docker environment by stopping and removing all containers, images, volumes, and non-default networks. Useful for resetting your Docker environment during development.

**Note:** You may need to make these scripts executable before use:

```sh
chmod +x tools/*.sh
```

---

## Notes

- This image is built to be non-root. In order to use Docker, you must utilize a remote Docker setup.
- For remote Docker, ensure the host is reachable and SSH keys are valid.
- For Kubernetes/Helm, mount secrets for SSH keys as needed.
- The container configures Zsh for the `coder` user and ensures `/home/coder/.local/bin` is in the PATH.
