#!/bin/bash

if [[ $HOSTNAME == "nas" ]]; then
    download_proton() {
        local jq_cmd="jq -r .assets.[].browser_download_url"
        local tar_file="$1.$3"
        local nas_dest="/mnt/NAS/Backup/Linux/Proton/$1/$tar_file"
        wcurl --curl-options="--clobber" -o "$nas_dest" "$(curl -s "$2" | $jq_cmd | $4)"
    }

    download_protonge() {
        local proton="proton-ge"
        local github_url="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
        local file_ext="tar.gz"
        local grep_cmd="grep -v -e aarch64 -e sha512sum"
        download_proton "$proton" "$github_url" "$file_ext" "$grep_cmd"
    }

    download_protoncachyos() {
        local proton="proton-cachyos"
        local github_url="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"
        local file_ext="tar.xz"
        local grep_cmd="grep -v -e arm64 -e sha512sum -e x86_64_v3"
        download_proton "$proton" "$github_url" "$file_ext" "$grep_cmd"
    }
else
    download_proton() {
        local proton="proton-$1"
        local dest="$XDG_DATA_HOME/Steam/compatibilitytools.d/$proton-latest"
        local tar_file="$proton.$2"
        if [[ -d $dest ]]; then
            sudo rm -r "$dest"
            scp "$USER@nas:/mnt/NAS/Backup/Linux/Proton/$proton/$tar_file" "$PWD"
            tar -xf "$tar_file" --one-top-level="$dest" --strip-components 1
            ln -sf "$HOME/Sync/Config/Gaming/Proton/$proton/$HOSTNAME/user_settings.py" "$dest"/user_settings.py
        fi

        if [[ -f $tar_file ]]; then
            rm "$tar_file"
        fi
    }

    download_protonge() {
        download_proton "ge" "tar.gz"
    }

    download_protoncachyos() {
        download_proton "cachyos" "tar.xz"
    }
fi
