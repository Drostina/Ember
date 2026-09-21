#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

sed -i \
    -e 's/^NAME=.*/NAME="Ember"/' \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Ember"/' \
    -e 's/^LOGO=.*/LOGO=ember-logo-icon/' \
    -e 's/^ANSI_COLOR=.*/ANSI_COLOR="0;38;2;255;134;102"/' \
    /usr/lib/os-release

grep -Fxq 'NAME="Ember"' /usr/lib/os-release
grep -Fxq 'PRETTY_NAME="Ember"' /usr/lib/os-release
grep -Fxq 'LOGO=ember-logo-icon' /usr/lib/os-release
grep -Fxq 'ANSI_COLOR="0;38;2;255;134;102"' /usr/lib/os-release

install -Dm644 /ctx/cosign.pub /etc/pki/containers/ember.pub
policy_tmp=$(mktemp)
jq -e -f /ctx/ember-policy.jq /etc/containers/policy.json > "$policy_tmp"
install -m644 "$policy_tmp" /etc/containers/policy.json
rm "$policy_tmp"

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

gtk-update-icon-cache -f /usr/share/icons/hicolor
glib-compile-schemas /usr/share/glib-2.0/schemas

kernel_version="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"
test -f "/usr/lib/modules/$kernel_version/vmlinuz"
dracut --no-hostonly --kver "$kernel_version" --reproducible --zstd -v \
    --add ostree --add fido2 -f "/usr/lib/modules/$kernel_version/initramfs.img"
chmod 0600 "/usr/lib/modules/$kernel_version/initramfs.img"
