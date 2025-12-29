dx-without-dx: install-pkgs setup-vscode setup-virt create-fbuilder-wrapper
    @echo ""
    @echo "✅ You are now dx ready!"

install-pkgs:
    brew bundle install --file "dx.brewfile"

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


setup-virt:
    #!/usr/bin/env bash
    set -euo pipefail
    brew install dnsmasq qemu libvirt
    flatpak install org.virt_manager.virt-manager
    flatpak run org.virt_manager.virt-manager -c "qemu:///session?socket=/run/user/$(id -u $USER)/libvirt/libvirt-sock" &

    mkdir -p ~/.config/systemd/user/

    cat > "$HOME/.config/systemd/user/libvirtd-brew.service" <<'EOF'
    #!/bin/sh
    [Unit]
    Description=Run brew's version of libvirtd in the background

    [Service]
    Type=simple
    ExecStart=/home/linuxbrew/.linuxbrew/sbin/libvirtd
    Environment="PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/bin:/bin"
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=default.target
    EOF

    systemctl --user daemon-reload
    systemctl --user enable --now libvirtd-brew.service


    echo "✅ Virt setup ready to use!"

# Create wrapper for flatpak-builder
create-fbuilder-wrapper:
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p ~/.local/bin
    cat > "$HOME/.local/bin/flatpak-builder" <<'EOF'
    #!/bin/sh
    exec flatpak run --command="flatpak-builder" "org.flatpak.Builder" "$@"
    EOF
    chmod +x "$HOME/.local/bin/flatpak-builder"
    echo "Please add ~/.local/bin to your path"
    echo "✅ Flatpak-Builder wrapper created"
