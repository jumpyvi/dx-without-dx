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
    flatpak run org.virt_manager.virt-manager -c "qemu:///session" &

    mkdir -p ~/.local/bin

    flatpak run --command=sh org.virt_manager.virt-manager -c 'ls -1 /app/lib/extensions/bin/ 2>/dev/null' | while read -r cmd; do
        case "$cmd" in
            *.la|*.a|*.txt|*.so|*.so.*) continue ;;
            *)
                wrapper_path="$HOME/.local/bin/$cmd"
                cat > "$wrapper_path" <<EOF
    #!/bin/sh
    exec flatpak run --command="$cmd" "org.virt_manager.virt-manager" "\$@"
    EOF
                chmod +x "$wrapper_path"
                ;;
        esac
    done

    cat > "$HOME/.local/bin/virsh" <<'EOF'
    #!/bin/sh
    exec flatpak run --command="virsh" "org.virt_manager.virt-manager" "$@"
    EOF
    chmod +x "$HOME/.local/bin/virsh"

    echo ""
    echo "Please add ~/.local/bin to your path"
    echo "✅ Qemu wrappers created"

# Create wrapper for flatpak-builder
create-fbuilder-wrapper:
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p ~/.local/bin
    cat > "$HOME/.local/bin/flatpak-builder" <<'EOF'
    #!/bin/sh
    exec flatpak run --command="flatpak-builder" "org.flatpak.Builder" "$@"
    EOF
    chmod +x "$wrapper_path"
    echo "Please add ~/.local/bin to your path"
    echo "✅ Flatpak-Builder wrapper created"
