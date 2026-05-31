#!/bin/bash

# General

mkcd() {
    # $1 - directory name
    mkdir -p -- "$1" && cd -P -- "$1"
}

nvme_health() {
    # $1 - NVME device number
    sudo nvme smart-log -H /dev/nvme$1
}

to_7z() {
    7z a -mx9 "${1%.$2}.7z" "$1"
}

to_zst() {
    # $1 - file or folder to be compressed
    tar -I "zstd --ultra -22 -T$(nproc)" -cf $1.tar.zst $1
}

if [[ -f /usr/bin/docker ]] then
    docker_kill() {
        # $1 - Container ID
        docker kill $1
        docker rm $1
        docker container prune
    }

    docker_update() {
        local docker_file="$HOME/Sync/Scripts/Docker/docker-compose.yaml"
        docker-compose -f $docker_file pull
        docker-compose -f $docker_file up -d
        docker image prune -af
    }
fi

if [[ -f /usr/bin/flatpak ]] then
    remove_flatpak() {
        flatpak uninstall --all --delete-data
        rm -r $HOME/.var
        rm -r $XDG_CACHE_HOME/flatpak
        rm -r $XDG_STATE_HOME/flatpak
        sudo rm -r /var/lib/flatpak
        sudo pacman -Rncs flatpak
    }

    remove_flatpak_app() {
        flatpak uninstall $1 --delete-data
    }
fi

update() {
    if [[ -f /usr/bin/pacman ]] then
        sudo pacman -Syu
        if [[ -f /usr/bin/yay ]] then
            yay -a
        fi
        if [[ -f /usr/bin/paccache ]] then
            paccache -r -k 0
        fi
    elif [[ -f /usr/bin/dnf ]] then
        sudo dnf upgrade
    elif [[ -f /usr/bin/apt ]] then
        sudo apt update && sudo apt upgrade
    fi

    if [[ -f /usr/bin/flatpak ]] then
        flatpak update && flatpak remove --unused
    fi

    if [[ -f /usr/bin/docker ]] then
        docker_update
    fi

    if [[ -f /usr/bin/fwupdmgr ]] then
        fwupdmgr refresh
        fwupdmgr get-updates
        fwupdmgr update
    fi
}

remove() {
    if [[ -f /usr/bin/pacman ]] then
        sudo pacman -Rncs $1
    elif [[ -f /usr/bin/dnf ]] then
        sudo dnf remove $1
    elif [[ -f /usr/bin/apt ]] then
        sudo apt remove $1
    fi
}

if [[ -f /usr/bin/pacman ]] then
    pacin() {
        sudo pacman -U *.$1
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

    if [[ -f /usr/bin/pkgctl ]] then
        download_arch_package() {
            pkgctl repo clone --protocol=https $1
        }

        patch_kernel() {
            local patches="$HOME/Sync/Config/Kernel/$1"
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
            time makepkg -s --skipinteg --asdeps
            cd ../
            sudo rm -r $kernel
        }
    fi
fi

# Media

if [[ -f /usr/bin/mkvmerge ]] then
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
        mkvpropedit "$1" --edit track:$2$3 --set flag-default=$4
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
        local track_type=""
        local track_num=""
        local track_default=""

        readarray -t video_list < <(find -type f -iname "*.mkv")

        for video in "${video_list[@]}"; do
            mkv_default_track "$video" $1 $2 $3
        done
    }

    remove_tracks() {
        # $1 - Video file
        # $2 - Track ID of audio track to keep
        # $3 - Track ID of subtitle track to keep
        mkvmerge -o "Muxed/$1" -a $2 -s $3 "$1"
    }

    to_mkv() {
        # $1 - File extension to convert
        find -type f -iname "*.$1" | parallel mkvmerge -o "{.}.mkv" "{}"
    }

    batch_remove_tracks() {
        # Audio and Subtitle tracks not chosen by $1 and $2 will be removed
        find -type f -iname "*.mkv" \
            | parallel mkvmerge -o "Muxed/{}" -a $1 -s $2 "{}"
    }

    add_subs() {
        local video_ext=""
        read -p "Video File Extension Type: " video_ext
        find -type f -iname "*.$videoExt" \
            | parallel mkvmerge -o "Muxed/{.}.mkv" "{}" "{.}"*.srt
    }
fi

if [[ -f /usr/bin/ffmpeg ]] then
    rencode() {
        # $1 Video file type
        # if the input file is mkv output the file in a different directory
        local video_list=()

        if [[ $1 != "mkv" ]] then
            dest="."
        else
            dest="Re-Encoded"
            mkdir $dest
        fi

        readarray -t video_list < <(find -type f -name "*.$1")

        for video in "${video_list[@]}"; do
            ffmpeg -nostdin -vaapi_device /dev/dri/renderD128 -i "$video" -vf 'format=nv12,hwupload' -c:v av1_vaapi -b:v $2M -c:a copy "$dest/${video%.*}.mkv"
        done
    }
fi


if [[ -f /usr/bin/cjxl ]] then
    to_jxl() {
        find -type f -iname "*.$1" | parallel cjxl "{}" "{.}.jxl"
    }
fi

# Removes Dolby Vision from MKV HEVC HDR files
# $1 file name of the video
if [[ -f /usr/lib/jellyfin-ffmpeg/ffmpeg ]] then
    remove_dolby_vision() {
        mkvpropedit "$1" --delete-attachment mime-type:image/png
        mkvpropedit "$1" --delete-attachment mime-type:image/jpeg
        mv "$1" "$1".bak
        /usr/lib/jellyfin-ffmpeg/ffmpeg -y -hide_banner -stats -fflags +genpts+igndts -loglevel error -i "$1".bak -map 0 -bsf:v hevc_metadata=remove_dovi=1 -codec copy -max_muxing_queue_size 2048 -max_interleave_delta 0 -avoid_negative_ts disabled "$1"
        if [[ $(stat --printf="%s" "$1") == 0 ]] then
            rm "$1"
        fi
        if [[ -f "$1" ]] then
            echo "Dolby vision removed"
            rm "$1".bak
        else
            mv "$1".bak "$1"
            echo "Mission failed we'll get em next time"
        fi
    }
fi

# Gaming

vulkan_git_test() {
    $HOME/Sync/Scripts/Gaming/Mesa/mesa_git.sh vkcube
}

github_download() {
    # $1 - file extension of the file to be downloaded
    # $2 - JSON url to scrape the links from
    wcurl $(curl -s $2 | jq -r .assets.[].browser_download_url | grep $1)
}

download_protonge() {
    local protonge_file='/mnt/NAS/Temp/ProtonGE/GE-Proton-latest.tar.gz'

    if [[ $HOSTNAME == 'nas' ]] then
        github_download .tar.gz "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
        mv GE-Proton*.tar.gz $protonge_file
    else
        local dest="$XDG_DATA_HOME/Steam/compatibilitytools.d/GE-Proton-latest"
        rm -rf "$dest"
        scp $USER@nas:$protonge_file $PWD
        mkdir "$dest"
        tar -xf GE-Proton-latest.tar.gz -C "$dest" --strip-components 1
        ln -s $HOME/Sync/Config/Gaming/Proton/$HOSTNAME/user_settings.py "$dest"/user_settings.py
        rm ./GE-Proton*.tar.gz
    fi
}

# Gaming - GPU

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
