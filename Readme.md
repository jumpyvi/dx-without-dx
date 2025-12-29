# Experimental just file for dx-less bluefins

# Available

## dx-without-dx
Will run all the commands, you will be fully dx-ready

## setup-vscode
Setup vscode with devcontainer using podman
> [!WARNING]  
> If you already have a vscode config, the vscode config part might fail, you can manually add the following to your vscode config:
> ```jsonc
>"dev.containers.dockerComposePath": "podman-compose",
>"dev.containers.dockerPath": "podman",
>"dev.containers.dockerSocketPath": "/run/user/1000/>podman/podman.sock"
>```

## setup-virt
Will setup virt-manager and connect it to brew's qemu and libvirt

Qemu/Virt utils will be in your accessible from your shell if brew is in your path
> [!NOTE]  
> This will enable a user-wide unit at `~/.config/systemd/user/libvirtd-brew.service`

## install-pkgs
This will install all the package I could find in homebrew/flathub to replicate the -dx setup

## create-fbuilder-wrapper
Create a simple wrapper so you can easily acces `flatpak-builder`


# Missing
- Rootful docker