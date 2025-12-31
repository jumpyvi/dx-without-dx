#Manual service run
#sudo env PATH=$PATH:/home/linuxbrew/.linuxbrew/bin \
#  /home/linuxbrew/.linuxbrew/sbin/libvirtd \
#  -f /home/linuxbrew/.linuxbrew/etc/libvirt/libvirtd.conf

#sudo /home/linuxbrew/.linuxbrew/sbin/virtlogd \
#  -f /home/linuxbrew/.linuxbrew/etc/libvirt/virtlogd.conf

setup-virt-system:
    #!/usr/bin/env bash
    brew install qemu libvirt
    flatpak install org.virt_manager.virt-manager -y

    # Group/User creations
    sudo groupadd libvirt || true
    sudo useradd -r -M -s /sbin/nologin libvirt-qemu || true
    sudo usermod -aG libvirt $(whoami)

    # Setup dirs
    sudo mkdir -p /var/lib/libvirt/images /var/run/libvirt
    sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images
    sudo chmod 750 /var/lib/libvirt/images

    # Conf files edit. Replace, then append
    QEMU_CONF="/home/linuxbrew/.linuxbrew/etc/libvirt/qemu.conf"
    LIBVIRT_CONF="/home/linuxbrew/.linuxbrew/etc/libvirt/libvirtd.conf"
    
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

    BREW_PREFIX="/var/home/linuxbrew/.linuxbrew"

    cat <<EOF | sudo tee /etc/systemd/system/virtlogd.service
    [Unit]
    Description=Virtual machine log manager (Homebrew)
    Documentation=man:virtlogd(8)

    [Service]
    SELinuxContext=system_u:system_r:unconfined_service_t:s0
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
    SELinuxContext=system_u:system_r:unconfined_service_t:s0
    Environment="PATH=$PATH:$BREW_PREFIX/bin"
    ExecStart=$BREW_PREFIX/sbin/libvirtd -f $BREW_PREFIX/etc/libvirt/libvirtd.conf
    ExecReload=/bin/kill -HUP \$MAINPID
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    EOF

    sudo systemctl daemon-reload
    sudo systemctl start virtlogd.service libvirtd.service

    # Setup virt-manager connection
    flatpak run org.virt_manager.virt-manager -c "qemu:///system?socket=/run/libvirt/libvirt-sock" --show-host-summary &