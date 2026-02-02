#!/bin/bash
#
# Functions for compressing game roms

if [[ -f /usr/bin/chdman ]] then
    # Compress a single rom file
    # $1 - Compression Method (dvd or cd)
    # $2 - Source file
    crom() {
        chdman create$1 -f -i "$2" -o "${2%.*}.chd"
    }

    # Compresses multiple rom files at once
    # $1 - Compression Method (dvd, cd or 7z)
    crom_batch() {
        case $1 in
        "dvd")
            find -type f -iname "*.iso" -or -iname "*.bin" | parallel chdman createdvd -f -i "{}" -o "{.}.chd"
            ;;
        "cd")
            find -type f -iname "*.cue" | parallel chdman createcd -f -i "{}" -o "{.}.chd"
            ;;
        "7z")
            find -type f -iname "*.$2" | parallel --bar 7z a -mx9 "{.}.7z" "{}"
            ;;
        *)
            echo "Incorrect or no option chosen"
        esac
    }
fi
