#!/bin/bash

luksMenu() {
    local luks_disk
    luks_disk="$(systemd-cryptenroll --list-devices | grep -m1 /dev)"
    local choice=""

    echo "LUKS Menu"
    echo "1. list "
    echo "2. Add FIDO2 key"
    echo "3. Delete FIDO2 keys"
    echo
    echo "LUKS Disk: $luks_disk"
    echo
    read -rp "Choose an option: " choice

    case $choice in
        "1")
            sudo systemd-cryptenroll $luks_disk
            ;;
        "2")
            sudo systemd-cryptenroll $luks_disk --fido2-device=auto --fido2-credential-algorithm=eddsa --fido2-with-client-pin=no
            ;;
        "3")
            sudo systemd-cryptenroll $luks_disk --wipe-slot fido2
            ;;
        *)
            echo "Incorrect or no option chosen"
            return
    esac
}
