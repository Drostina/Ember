#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

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
