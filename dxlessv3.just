

setup-docker-rootful:
    #!/usr/bin/env bash
    echo "This is meant to run on non-DX Bluefin, GnomeOS/Dakota or Zirconium"

    if ! groups "$USER" | grep -q "\bdocker\b"; then
        echo "User '$USER' is not in the docker group. User added, please reboot."
        sudo mkdir -p /etc/sysusers.d/ && printf "m %s docker\n" "$(whoami)" | sudo tee /etc/sysusers.d/docker.conf > /dev/null
        exit 0
    fi

    sudo -v
    brew install --cask ublue-os/experimental-tap/dockerd-linux
    sudo cp ./services/brew-containerd.service /etc/systemd/system/
    sudo cp ./services/brew-dockerd.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl start brew-containerd.service brew-dockerd.service
    sudo -k
    /home/linuxbrew/.linuxbrew/bin/docker context use default
    docker info
    echo "Services where started, but not enabled. They are named brew-containerd.service and brew-dockerd.service"

setup-vscode:
    #!/usr/bin/env bash
    set -euo pipefail
    brew tap ublue-os/tap
    brew install --cask visual-studio-code-linux
    brew install podman-compose
    code --install-extension "ms-vscode-remote.remote-containers"
    systemctl enable --user --now podman.socket

    VS_SETTINGS="$HOME/.config/Code/User/settings.json"
    mkdir -p "$(dirname "$VS_SETTINGS")"

    # Create empty settings file if it doesn't exist
    [[ -f "$VS_SETTINGS" ]] || echo '{}' > "$VS_SETTINGS"

    jq -n --slurpfile old "$VS_SETTINGS" '
    ($old[0] // {}) +
    {
        "dev.containers.dockerComposePath": "podman-compose",
        "dev.containers.dockerPath": "podman",
        "dev.containers.dockerSocketPath": "/run/user/1000/podman/podman.sock"
    }
    ' > "$VS_SETTINGS.tmp" && mv "$VS_SETTINGS.tmp" "$VS_SETTINGS"

    echo "✅ VS Code settings updated for Podman"


create-fbuilder-wrapper:
    #!/usr/bin/env bash

    mkdir -p ~/.local/bin
    cat > "$HOME/.local/bin/flatpak-builder" <<'EOF'
    #!/bin/sh
    exec flatpak run --command="flatpak-builder" "org.flatpak.Builder" "$@"
    EOF
    chmod +x "$HOME/.local/bin/flatpak-builder"
    echo "Please add ~/.local/bin to your path"
    echo "✅ Flatpak-Builder wrapper created"

create-bst-wrapper:
    #!/usr/bin/env bash

    mkdir -p ~/.local/bin
    cat > "$HOME/.local/bin/bst" <<'EOF'
    #!/bin/sh
    exec podman run -it --rm --privileged --name "bst2-container-$(date +%s)" --user "$(id -u):$(id -g)" --userns=keep-id --workdir "$PWD" -v "$HOME:$HOME" registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2 bst "$@"
    EOF
    chmod +x "$HOME/.local/bin/bst"
    echo "Please add ~/.local/bin to your path"
    echo "✅ Buildstream wrapper created"
    
