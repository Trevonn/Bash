#!/bin/bash

download_proton() {
    local jq_cmd="jq -r .assets.[].browser_download_url"
    local tar_file="$1.$3"
    local nas_dest="/mnt/NAS/Backup/Linux/Proton/$1/$tar_file"
    if [[ $HOSTNAME == "nas" ]]; then
        wcurl --curl-options="--clobber" -o "$nas_dest" "$(curl -s "$2" | $jq_cmd | $4)"
    else
        local dest="$XDG_DATA_HOME/Steam/compatibilitytools.d/$1-latest"
        if [[ -d "$dest" ]]; then
            sudo rm -r "$dest"
        fi
        scp "$USER@nas:$nas_dest" "$PWD"
        tar -xf "$tar_file" --one-top-level="$dest" --strip-components 1
        rm "$tar_file"
        ln -s "$HOME/Sync/Config/Gaming/Proton/$1/$HOSTNAME/user_settings.py" "$dest"/user_settings.py
    fi
}

download_protonge() {
    local proton_rel="proton-ge"
    local github_url="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
    local file_ext="tar.gz"
    local grep_cmd="grep -v -e aarch64 -e sha512sum"
    download_proton "$proton_rel" "$github_url" "$file_ext" "$grep_cmd"
}

download_protoncachyos() {
    local proton_rel="proton-cachyos"
    local github_url="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"
    local file_ext="tar.xz"
    local grep_cmd="grep -v -e arm64 -e sha512sum -e x86_64_v3"
    download_proton "$proton_rel" "$github_url" "$file_ext" "$grep_cmd"
}
