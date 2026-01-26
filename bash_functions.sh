#!/bin/bash

# General

mkcd() {
    mkdir -p -- "$1" && cd -P -- "$1"
}

nvme_health() {
    sudo nvme smart-log -H /dev/nvme$1
}

to_7z() {
    7z a -mx9 "${1%.$2}.7z" "$1"
}

to_zst() {
    tar -I "zstd --ultra -22 -T$(nproc)" -cf $1.tar.zst $1
}

docker_kill() {
    docker kill $1
    docker rm $1
    docker container prune
}

docker_update() {
    docker_file="$SYNC_DIR/Scripts/Docker/docker-compose.yaml"
    docker-compose -f $docker_file pull
    docker-compose -f $docker_file up -d
    docker image prune -af
}

if [[ -f /usr/bin/flatpak ]] then
    remove_flatpak() {
        flatpak uninstall --all --delete-data
        rm -r $HOME/.var
        rm -r $XDG_CACHE_HOME/flatpak
        rm -r $XDG_STATE_HOME/flatpak
        sudo rm -r /var/lib/flatpak
        sudo pacman -Rncs flatpak
    }
fi

download_music() {
    yt-dlp --format 251 --extract-audio --audio-format "opus" $1 -o "%(title)s.%(ext)s"
}

mkv_default_track() {
    mkvpropedit $1 --edit track:$2$3 --set flag-default=$4 --set flag-forced=$5
}

mkv_default_track_batch() {
    echo "MKV Default Track Changer Batch 1.0"
    echo "This script lets you change the default track properties in an MKV"
    echo
    local track_type=""
    local track_num=""
    local track_default=""

    echo "MKV Default Track Selector"
    read -p "Default track type: audio or subtitle (a/s): " track_type
    read -p "Choose a track number: " track_num
    read -p "Set the track number as default? (0,1): " track_default

    find -type f -iname "*.mkv" | while read film
        do
            mkvpropedit "$film" --edit track:$track_type$track_num --set flag-default=$track_default
        done
}

downsample_video_audio() {
    mkdir Muxed
    find -type f -iname "$1" | parallel ffmpeg -y -i "{}" -map 0 -c copy -c:a:0 aac -b:a:0 256k -ac 2 "Muxed/{}"
}

to_mkv() {
    find -type f -iname "*.$1" | parallel mkvmerge -o "{.}.mkv" "{}"
}

remove_tracks() {
    mkvmerge -o "Muxed/$1" -a $2 -s $3 "$1"
}

batch_remove_tracks() {
    # Audio and Subtitle tracks not chosen by $1 and $2 will be removed
    find -type f -iname "*.mkv" | parallel mkvmerge -o "Muxed/{}" -a $1 -s $2 "{}"
}

add_subs() {
    local video_ext=""
    read -p "Video File Extension Type: " videoExt
    find -type f -iname "*.$videoExt" | parallel mkvmerge -o "Muxed/{.}.mkv" "{}" "{.}"*.srt
}

to_jxl() {
    find -type f -iname "*.$1" | parallel cjxl "{}" "{.}.jxl"
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

if [[ -f /usr/bin/pacman ]] then
    pacin() {
        sudo pacman -U *.$1
    }
fi

# Media

video_state() {
    # $1 The file containing the list of videos
    cat $1 | while read video
    do
        if [[ -f "$video" ]] then
            mv "$video" "$video".bak
            echo "Disabled $video"
        elif [[ -f "$video.bak" ]] then
            mv "$video".bak "$video"
            echo "Restored $video"
        else
            echo "Video not found: $video"
        fi
    done
}

rencode_10() {
    # if the input file is mkv output the file in a different directory
    if [[ $1 != "mkv" ]] then
        dest="."
    else
        dest="Re-Encoded"
        mkdir $dest
    fi

    find -type f -name "*.$1" | while read video
    do
        ffmpeg -nostdin -vaapi_device /dev/dri/renderD128 -i "$video" -vf 'format=nv12,hwupload' -c:v av1_vaapi -b:v 10M -c:a copy "$dest/${video%.*}.mkv"
    done
}

to_flac() {
    find -type f -iname "*.$1" | parallel ffmpeg -i "{}" -c:a flac -sample_fmt s32 "{.}.flac"
}

# Bulk converts flac files to opus files
# $1 bitrate of the opus file. For example 160000
flac_to_opus() {
    find -type f -iname "*.flac" | parallel ffmpeg -i "{}" -c:a libopus -b:a $1 "{.}.opus"
}

tag_music() {
    case $1 in
    "title")
        kid3-cli -c "select *.opus" -c "totag '%{title}' 2"
        ;;
    "album")
        kid3-cli -c "select *.opus" -c "set Album '$2'"
        ;;
    *)
        echo "Argument must be title or album"
    esac
}


# Removes Dolby Vision from MKV HEVC HDR files
# $1 file name of the video
if [[ -f /usr/lib/jellyfin-ffmpeg/ffmpeg ]] then
    remove_dolby_vision() {
        mkvpropedit "$1" --delete-attachment mime-type:image/png
        mkvpropedit "$1" --delete-attachment mime-type:image/jpeg
        /usr/lib/jellyfin-ffmpeg/ffmpeg -y -hide_banner -stats -fflags +genpts+igndts -loglevel error -i "$1" -map 0 -bsf:v hevc_metadata=remove_dovi=1 -codec copy -max_muxing_queue_size 2048 -max_interleave_delta 0 -avoid_negative_ts disabled "${1%.*}-nodv.mkv"
    }
fi

# Gaming

# Gaming - Emulation

# Extracts mounted PS3 disc to the RPCS3 disc folder
# $1 Name of the game
extract_ps3_disc() {
    local dest=$ROMS_DIR/Sony/PS3/games/"$1"
    rsync -ahW --info=progress2 --no-compress --mkpath --chmod=755 {PS3_GAME,PS3_DISC.SFB} "$dest"
}

# Gaming-Wine

github_download() {
    # $1 = file extension of the file to be downloaded
    wcurl $(curl -s $2 | jq -r .assets.[].browser_download_url | grep $1)
}

download_protonge() {
    local dest="$XDG_STATE_HOME/Steam/compatibilitytools.d/GE-Proton-latest"
    rm -rf "$dest"
    github_download .tar.gz "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
    mkdir "$dest"
    tar -xf GE-Proton*.tar.gz -C "$dest" --strip-components 1
    ln -s $HOME/Sync/Config/Gaming/Steam/user_settings.py "$dest"/user_settings.py
    rm GE-Proton*.tar.gz
}

download_dxvk() {
    github_download .gz "https://api.github.com/repos/doitsujin/dxvk/releases/latest"
    tar -xf dxvk*.tar.gz -C $HOME/Games/DirectX/DXVK --strip-components 1
    rm dxvk*.tar.gz
}

download_vkd3d-proton() {
    github_download .zst "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest"
    tar -xf vkd3d*.tar.zst -C $HOME/Games/DirectX/VKD3D-Proton --strip-components 1
    rm vkd3d*.tar.zst
}

# Gaming-GPU

change_gpu_state() {
    local gpu_level="/sys/class/drm/card1/device/power_dpm_force_performance_level"
    echo "Current GPU Level: $(cat $gpu_level)"
    echo "Setting GPU Level to $1"
    echo $1 | sudo tee "$gpu_level" > /dev/null
    echo "Current GPU Level: $(cat $gpu_level)"
}

reset_gpu() {
    local gpu_config_file="/sys/class/drm/card1/device/pp_od_clk_voltage"
    echo "r" > sudo tee $gpu_config_file > /dev/null
    echo "c" > sudo tee $gpu_config_file > /dev/null
}

gpu_power_cap() {
    local cap="$(find /sys/class/drm/card1/device/hwmon -type f -name power1_cap)"

    if [[ -f "$cap" ]] then
        cat "$cap"
    fi
}

# Misc

nas_backup() {
    timestamp=$(date +"%Y-%m-%d")
    backup_folder="/mnt/NAS/Backup/Auto/$timestamp"
    mkdir "$backup_folder"
    backup_file="$backup_folder/$1 - Backup - $timestamp.tar.zst"
    tar -I "zstd --ultra -22 -T$(nproc)" -cf "$backup_file" "$2"
}

if [[ -f /usr/bin/pkgctl ]] then
    download_arch_package() {
        pkgctl repo clone --protocol=https $1
    }

    patch_kernel() {
        local patches="$SYNC_DIR/Config/Kernel/$1"
        cp $patches/tsc.patch tsc.patch
        patch -i $patches/PKGBUILD.patch PKGBUILD
    }

    build_kernel() {
        local option=""
        local kernel=""
        echo "Kernel with TSC Patch builder"
        echo "1: linux"
        echo "2: linux-lts"
        read -p "Choose a kernel to build: " option
        if [[ $option == 1 ]] then
            kernel="linux"
        elif [[ $option == 2 ]] then
            kernel="linux-lts"
        fi
        sudo rm -r $kernel
        download_arch_package $kernel
        cd $kernel
        patch_kernel $kernel
        makepkg -s --skipinteg --asdeps
        cd ../
        sudo rm -r $kernel
    }
fi
