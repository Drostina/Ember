#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

install -Dm644 /ctx/cosign.pub /etc/pki/containers/ember.pub
policy_tmp=$(mktemp)
jq -e -f /ctx/ember-policy.jq /etc/containers/policy.json > "$policy_tmp"
install -m644 "$policy_tmp" /etc/containers/policy.json
rm "$policy_tmp"

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 install -y \
    --setopt=install_weak_deps=True \
    --setopt=exclude_from_weak=alacritty,waybar \
    niri \
    quickshell \
    xfce-polkit \
    kitty \
    fastfetch \
    pavucontrol \
    gnome-disk-utility \
    breeze-cursor-theme \
    jetbrains-mono-fonts-all \
    fontawesome-fonts-all \
    clang \
    cmake \
    ninja-build \
    nodejs \
    rust \
    cargo \
    swayidle \
    playerctl \
    brightnessctl \
    cava

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable ember-flatpak-setup.service
