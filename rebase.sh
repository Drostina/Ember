#!/usr/bin/env bash
set -euo pipefail

check_system() {
    if [[ ! -e /run/ostree-booted || -e /run/.containerenv || -e /.dockerenv ]]; then
        echo "Run this on an installed Bazzite system, not the live USB or a container." >&2
        return 1
    fi
    local ID
    source /usr/lib/os-release
    case "$ID" in
        bazzite|ember) ;;
        *) echo "This script is for switching Bazzite to Ember." >&2; return 1 ;;
    esac
}

main() (
    if [[ ${1:-} == --help && $# == 1 ]]; then
        echo "Usage: bash rebase.sh"
        echo "Switch installed Bazzite GNOME NVIDIA Open to signed Ember. Reboot manually afterward."
        exit 0
    fi
    if (( $# )); then
        echo "Usage: bash rebase.sh" >&2
        exit 1
    fi
    check_system
    for dependency in bootc curl jq openssl sudo; do
        command -v "$dependency" >/dev/null || { echo "Missing: $dependency" >&2; exit 1; }
    done

    echo "This will set up Ember's public signing key and switch to ghcr.io/drostina/ember:latest."
    echo "Your files and installed Flatpaks stay in place. Start from Bazzite GNOME NVIDIA Open."
    read -r -p "Continue? [y/N] " answer
    case "$answer" in y|Y|yes|YES) ;; *) exit 0 ;; esac

    work_dir=$(mktemp -d)
    trap 'rm -rf -- "$work_dir"' EXIT
    fetch() {
        curl --fail --silent --show-error --location --retry 3 \
            --connect-timeout 15 --max-time 60 "$@"
    }
    revision=$(fetch https://api.github.com/repos/Drostina/Ember/commits/main | jq -er '.sha')
    [[ $revision =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid repository revision." >&2; exit 1; }
    source_url="https://raw.githubusercontent.com/Drostina/Ember/$revision"
    fetch "$source_url/cosign.pub" -o "$work_dir/ember.pub"
    fetch "$source_url/build_files/ember-policy.jq" -o "$work_dir/ember-policy.jq"
    fetch "$source_url/system_files/etc/containers/registries.d/ember.yaml" -o "$work_dir/ember.yaml"
    openssl pkey -pubin -in "$work_dir/ember.pub" -noout

    sudo -v
    sudo cat /etc/containers/policy.json > "$work_dir/original-policy.json"
    jq -e -f "$work_dir/ember-policy.jq" "$work_dir/original-policy.json" > "$work_dir/policy.json"
    backup_dir=$(sudo mktemp -d /etc/containers/ember-trust-backup.XXXXXX)
    sudo cp -a /etc/containers/policy.json "$backup_dir/policy.json"
    for path in /etc/pki/containers/ember.pub /etc/containers/registries.d/ember.yaml; do
        if sudo test -e "$path"; then
            sudo cp -a "$path" "$backup_dir/"
        fi
    done
    echo "Previous trust files saved in $backup_dir"

    sudo install -Dm644 "$work_dir/ember.pub" /etc/pki/containers/ember.pub
    sudo install -Dm644 "$work_dir/ember.yaml" /etc/containers/registries.d/ember.yaml
    sudo install -m644 "$work_dir/policy.json" /etc/containers/policy.json
    if command -v restorecon >/dev/null; then
        sudo restorecon /etc/pki/containers/ember.pub /etc/containers/registries.d/ember.yaml /etc/containers/policy.json
    fi
    sudo bootc switch --enforce-container-sigpolicy ghcr.io/drostina/ember:latest
    echo "Ember is ready for the next boot. Reboot when you're ready."
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
