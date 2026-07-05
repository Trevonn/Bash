#!/bin/bash

# General

nvme_health() {
    # $1 - NVME device number
    sudo nvme smart-log -H /dev/nvme"$1"
}

to_7z() {
    7z a -mx9 "$1.7z" "$1"
}

to_zst() {
    # $1 - file or folder to be compressed
    tar -I "zstd --ultra -22 -T$(nproc)" -cf "$1".tar.zst "$1"
}

# Package Management

# Docker

if [[ -f /usr/bin/docker ]]; then
    docker_kill() {
        # $1 - Container ID
        docker kill "$1"
        docker rm "$1"
        docker container prune
    }

    docker_update() {
        local docker_file="$HOME/Sync/Scripts/Docker/docker-compose.yaml"
        docker-compose -f "$docker_file" pull
        docker-compose -f "$docker_file" up -d
        docker image prune -af
    }
fi

# Flatpak

if [[ -f /usr/bin/flatpak ]]; then
    remove_flatpak() {
        flatpak uninstall --all --delete-data
        rm -r "$HOME/.var"
        rm -r "$XDG_CACHE_HOME/flatpak"
        rm -r "$XDG_STATE_HOME/flatpak"
        sudo rm -r /var/lib/flatpak
        sudo pacman -Rncs flatpak
    }

    remove_flatpak_app() {
        flatpak uninstall "$1" --delete-data
    }

    update_flatpak() {
        flatpak update && flatpak remove --unused
    }
fi

# Arch Linux

if [[ -f /usr/bin/pacman ]]; then
    update() {
        sudo pacman -Syu
        if [[ -f /usr/bin/yay ]]; then
            yay -a
        fi
        if [[ -f /usr/bin/paccache ]]; then
            paccache -r -k 0
        fi
        if [[ -f /usr/bin/flatpak ]]; then
            update_flatpak
        fi
    }

    remove() {
        sudo pacman -Rncs "$1"
    }

    pacin() {
        sudo pacman -U ./*."$1"
    }

    storage_cleanup() {
        yay -Scc
        sudo rm -r /var/log/*
        echo "Cleared /var/log/"
        sudo rm -r /var/cache/*
        echo "Cleared /var/cache/"
        sudo rm /var/lib/systemd/coredump/*
        echo "Cleared /var/lib/systemd/coredump"
    }

    if [[ -f /usr/bin/pkgctl ]]; then
        download_arch_package() {
            pkgctl repo clone --protocol=https "$1"
        }

        patch_kernel() {
            local patches="$HOME/Sync/Config/Kernel/$1"
            cp "$patches/tsc.patch" tsc.patch
            patch -i "$patches/PKGBUILD.patch" PKGBUILD
        }

        build_kernel() {
            local option=""
            local kernel=""
            echo "Kernel with TSC Patch builder"
            echo "1: linux"
            echo "2: linux-lts"
            read -rp "Choose a kernel to build: " option
            if [[ $option == 1 ]]; then
                kernel="linux"
            elif [[ $option == 2 ]]; then
                kernel="linux-lts"
            fi
            sudo rm -r $kernel
            download_arch_package $kernel
            cd $kernel || { echo "Unable to cd to $kernel"; exit 1; }
            patch_kernel $kernel
            time makepkg -s --skipinteg --asdeps
            cd ../
            sudo rm -r $kernel
        }
    fi
fi

# Fedora

if [[ -f /usr/bin/dnf ]]; then
    update() {
        sudo dnf upgrade
    }

    remove() {
        sudo dnf remove "$1"
    }
fi

# Debian

if [[ -f /usr/bin/apt ]]; then
    update() {
        sudo apt update && sudo apt upgrade
    }

    remove() {
        sudo apt remove "$1"
    }
fi

# Media

if [[ -f /usr/bin/mkvmerge ]]; then
    #######################################
    # Change default tracks of a single mkv file
    # Globals:
    # Arguments:
    #   $1 - mkv file
    #   $2 - track type - a or s
    #   $3 - track number
    #   $4 - track default - 0 or 1
    #######################################
    mkv_default_track() {
        mkvpropedit "$1" --edit track:"$2$3" --set flag-default="$4"
    }

    #######################################
    # Change default tracks of multiple MKV files
    # Globals:
    # Arguments:
    #   $1 - track type - a or s
    #   $2 - track number - integer
    #   $3 - track default - 0 or 1
    #######################################
    mkv_default_track_batch() {
        local video_list=()

        readarray -t video_list < <(find . -type f -iname "*.mkv")

        for video in "${video_list[@]}"; do
            mkv_default_track "$video" "$1" "$2" "$3"
        done
    }

    remove_tracks() {
        # $1 - Video file
        # $2 - Track ID of audio track to keep
        # $3 - Track ID of subtitle track to keep
        mkvmerge -o "Muxed/$1" -a "$2" -s "$3" "$1"
    }

    to_mkv() {
        # $1 - File extension to convert
        find . -type f -iname "*.$1" | parallel mkvmerge -o "{.}.mkv" "{}"
    }

    batch_remove_tracks() {
        # Audio and Subtitle tracks not chosen by $1 and $2 will be removed
        find . -type f -iname "*.mkv" \
            | parallel mkvmerge -o "Muxed/{}" -a "$1" -s "$2" "{}"
    }

    add_subs() {
        local video_ext=""
        read -rp "Video File Extension Type: " video_ext
        find . -type f -iname "*.$video_ext" \
            | parallel mkvmerge -o "Muxed/{.}.mkv" "{}" "{.}"*.srt
    }
fi

if [[ -f /usr/bin/ffmpeg ]]; then
    rencode() {
        # $1 Video file type
        # $2 Bitrate in megabits
        # if the input file is mkv output the file in a different directory
        local video_list=()

        if [[ $1 != "mp4" ]]; then
            dest="."
        else
            dest="Re-Encoded"
            mkdir $dest
        fi

        readarray -t video_list < <(find . -type f -name "*.$1")

        for video in "${video_list[@]}"; do
            ffmpeg -nostdin -vaapi_device /dev/dri/renderD128 -i "$video" -vf 'format=nv12,hwupload' -c:v av1_vaapi -b:v "$2"M -c:a copy "$dest/${video%.*}.mp4"
        done
    }
fi


if [[ -f /usr/bin/cjxl ]]; then
    to_jxl() {
        find . -type f -iname "*.$1" | parallel cjxl "{}" "{.}.jxl --effort=10"
    }
fi

# Removes Dolby Vision from MKV HEVC HDR files
# $1 file name of the video
if [[ -f /usr/lib/jellyfin-ffmpeg/ffmpeg ]]; then
    remove_dolby_vision() {
        mkvpropedit "$1" --delete-attachment mime-type:image/png
        mkvpropedit "$1" --delete-attachment mime-type:image/jpeg
        mv "$1" "$1".bak
        /usr/lib/jellyfin-ffmpeg/ffmpeg -y -hide_banner -stats -fflags +genpts+igndts -loglevel error -i "$1".bak -map 0 -bsf:v hevc_metadata=remove_dovi=1 -codec copy -max_muxing_queue_size 2048 -max_interleave_delta 0 -avoid_negative_ts disabled "$1"
        if [[ $(stat --printf="%s" "$1") == 0 ]]; then
            rm "$1"
        fi
        if [[ -f "$1" ]]; then
            echo "Dolby vision removed"
            rm "$1".bak
        else
            mv "$1".bak "$1"
            echo "Mission failed we'll get em next time"
        fi
    }
fi

# Gaming

download_proton() {
    local jq_cmd="jq -r .assets.[].browser_download_url"
    local tar_file="$1.$3"
    local nas_dest="/mnt/NAS/Temp/Proton/$1/$tar_file"
    if [[ $HOSTNAME == "nas" ]]; then
        wcurl --curl-options="--clobber" -o "$nas_dest" "$(curl -s $2 | $jq_cmd | $4)"
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

# Gaming - GPU

change_gpu_state() {
    local gpu_level="/sys/class/drm/card1/device/power_dpm_force_performance_level"
    echo "Current GPU Level: $(cat $gpu_level)"
    echo "Setting GPU Level to $1"
    echo "$1" | sudo tee "$gpu_level" > /dev/null
    echo "Current GPU Level: $(cat $gpu_level)"
}

reset_gpu() {
    local gpu_config_file="/sys/class/drm/card1/device/pp_od_clk_voltage"
    echo "r" | sudo tee $gpu_config_file > /dev/null
    echo "c" | sudo tee $gpu_config_file > /dev/null
}

gpu_power_cap() {
    local cap
    cap="$(find /sys/class/drm/card1/device/hwmon -type f -name power1_cap)"
    if [[ -f "$cap" ]]; then
        cat "$cap"
    fi
}
