#Manual service run
# sudo env \
#   PATH="$PATH:/home/linuxbrew/.linuxbrew/bin" \
#   DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket" \
#   /home/linuxbrew/.linuxbrew/sbin/libvirtd \
#   -f /home/linuxbrew/.linuxbrew/etc/libvirt/libvirtd.conf

#sudo /home/linuxbrew/.linuxbrew/sbin/virtlogd \
#  -f /home/linuxbrew/.linuxbrew/etc/libvirt/virtlogd.conf

setup-virt-system:
    #!/usr/bin/env bash
    brew install gum > /dev/null 2>&1 

    printf "⚠️ \033[31m This will pull a pre-built bottle from a third-party source (\033]8;;https://github.com/jumpyvi/homebrew-morebrew\033\\jumpyvi/morebrew\033]8;;\033\\)\033[0m\n"
    gum style --foreground "#eaff00ff" "You could also manually build from source from ublue-os/experimental-tap, but doing so caused major issues on my end"
    gum style --foreground "#006ff6ff" "🦖 This is also highly experimental, adventurous paleontologist only."
    ACCEPT=$(gum choose "I trust you!" "Cancel")
    
    if [ "$ACCEPT" = "I trust you!" ]; then

    gum spin --spinner dot --title "Installing virtualization packages... (it might take a while)" -- bash -c '
    set -e
    brew install qemu jumpyvi/morebrew/libvirt-full
    flatpak install -y org.virt_manager.virt-manager
    '

    # Group/User creations
    gum style --foreground "#006ff6ff" "Creating groups and users, please provide your password: "
    sudo groupadd libvirt || true
    sudo useradd -r -M -s /sbin/nologin libvirt-qemu || true
    sudo usermod -aG libvirt $(whoami)


    # Setup dirs
    gum spin --spinner dot --title "Creating directories..." -- bash -c '
    set -e
    sudo mkdir -p /var/lib/libvirt/images /var/run/libvirt
    sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images
    sudo chmod 750 /var/lib/libvirt/images
    '

    # Conf files edit. Replace, then append
    QEMU_CONF="/home/linuxbrew/.linuxbrew/etc/libvirt/qemu.conf"
    LIBVIRT_CONF="/home/linuxbrew/.linuxbrew/etc/libvirt/libvirtd.conf"
    cp $QEMU_CONF $(QEMU_CONF).bak
    cp $LIBVIRT_CONF $(LIBVIRT_CONF).bak

    gum style --foreground "#006ff6ff" "Original config files backed-up to $(brew --prefix)/etc/libvirt/{name}.conf.bak"
    
    sudo mkdir -p "$(dirname "$QEMU_CONF")"
    sudo touch "$QEMU_CONF" "$LIBVIRT_CONF"

    update() {
        local key=$1 value=$2 file=$3
        if sudo grep -q "^$key =" "$file"; then
            sudo sed -i "s|^$key =.*|$key = $value|" "$file"
        else
            echo "$key = $value" | sudo tee -a "$file" > /dev/null
        fi
    }

    # Apply settings
    update 'user' '"libvirt-qemu"' "$QEMU_CONF"
    update 'group' '"libvirt"' "$QEMU_CONF"
    update 'unix_sock_group' '"libvirt"' "$LIBVIRT_CONF"
    update 'unix_sock_rw_perms' '"0770"' "$LIBVIRT_CONF"
    update 'unix_sock_dir' '"/var/run/libvirt"' "$LIBVIRT_CONF"
    update 'auth_unix_ro' '"none"' "$LIBVIRT_CONF"
    update 'auth_unix_rw' '"none"' "$LIBVIRT_CONF"

    BREW_PREFIX="/var/home/linuxbrew/.linuxbrew"

    cat <<EOF | sudo tee /etc/systemd/system/virtlogd.service
    [Unit]
    Description=Virtual machine log manager (Homebrew)
    Documentation=man:virtlogd(8)

    [Service]
    Environment="LD_LIBRARY_PATH=/var/home/linuxbrew/.linuxbrew/lib"
    ExecStart=$BREW_PREFIX/sbin/virtlogd -f $BREW_PREFIX/etc/libvirt/virtlogd.conf
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    EOF

    # Create libvirtd service
    cat <<EOF | sudo tee /etc/systemd/system/libvirtd.service
    [Unit]
    Description=Virtualization daemon (Homebrew)
    Requires=virtlogd.service
    After=network.target virtlogd.service

    [Service]
    Environment="PATH=$PATH:$BREW_PREFIX/bin"
    Environment="DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket"
    ExecStart=$BREW_PREFIX/sbin/libvirtd -f $BREW_PREFIX/etc/libvirt/libvirtd.conf
    ExecReload=/bin/kill -HUP \$MAINPID
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    EOF

    gum spin --spinner dot --title "Starting services..." -- bash -c '
    set -e
    sudo systemctl daemon-reload
    sudo systemctl start virtlogd.service libvirtd.service
    '

    # Setup virt-manager connection
    flatpak run org.virt_manager.virt-manager -c "qemu:///system?socket=/run/libvirt/libvirt-sock" --show-host-summary &

    gum style --foreground "#16ff05ff" "Everything is done! Enjoy!"
    gum style --foreground "#05daffff" "The systemd unit are started, but not enabled. They are named libvirtd and virtlogd"
    gum style --foreground "#f705ffff" "Please share your virt installation experience in the bluefin discord!"
    fi