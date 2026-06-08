#!/bin/bash
#
# System information functions

# Gathers all the information about the current system
sys_info() {

    # Helper function to check if a file exists
    is_installed() {
        if [[ -f $1 ]]; then
            echo "Installed"
        else
            echo "Not installed"
        fi
    }

    cpu_freq=/sys/devices/system/cpu/cpu0/cpufreq/
    kernel_version=$(uname -r)
    glibc_version=$(ldd --version | grep ldd | awk '{print $4}')
    max_map_count=$(cat /proc/sys/vm/max_map_count)
    limit_NOFILE=$(ulimit -Hn)
    steam_udev_rules=$(is_installed /usr/lib/udev/rules.d/60-steam-input.rules)
    ram_qty="$(free -g | grep "Mem:" | awk '{print $ 2}') GB"
    cpu_name="$(lscpu | grep 'Model name' | cut -f 2 -d ":" | awk '{$1=$1}1')"
    cpu_temp="$(sensors | grep Tctl | grep -Po '\+\K.*')"
    cpu_threads="$(lscpu | grep -m 1 "CPU(s)" | awk '{print $2}')"
    cpu_cores="$(lscpu | grep "Core(s) per socket:" | awk '{print $4}') ($cpu_threads Threads)"
    cpu_gov=$(cat $cpu_freq/scaling_governor)
    cpu_driver=$(cat $cpu_freq/scaling_driver)
    turbo_boost="$(if [[ $(cat $cpu_freq/boost) == 1 ]]; then echo "On"; else echo "Off"; fi)"
    amd_pstate_mode=$(cat /sys/devices/system/cpu/amd_pstate/status)
    epp_pref="$(if [ -f $cpu_freq/energy_performance_preference ]; then cat $cpu_freq/energy_performance_preference; else echo "N/A"; fi)"
    clocksource="$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)"
    gpu_level=$(cat /sys/class/drm/card1/device/power_dpm_force_performance_level)
    gpu_name=$(DRI_PRIME=1! vulkaninfo --summary | grep "deviceName" | grep -Po '= \K.*')
    gpu_vram="$(DRI_PRIME=1! glxinfo -B | grep "Dedicated video memory:" | awk 'NR==1 { print $4 }') MB"
    driver_version=$(vulkaninfo | grep driverVersion | awk 'NR==1 { print $3 }')
    opengl_version=$(glxinfo | grep "OpenGL core profile version string" | awk '{ print $6 }')
    vulkan_version=$(vulkaninfo | grep apiVersion | awk 'NR==1 { print $3 }')
    mangohud_check=$(if [[ -f /usr/bin/mangohud ]]; then mangohud --version | grep -Po 'v\K.*'; else echo "Not installed"; fi)
    gamescope_check=$(is_installed /usr/bin/gamescope)
}

# The main function to display the system information
sys_check() {
    sys_info
    echo "System Check V2.2"
    echo
    echo "System"
    echo "......................"
    echo "Kernel               : $kernel_version"
    echo "glibc                : $glibc_version"
    echo "vm.max_map_count     : $max_map_count"
    echo "DefaultLimitNOFILE   : $limit_NOFILE"
    echo "RAM                  : $ram_qty"
    echo
    echo "CPU"
    echo "......................"
    echo "Name                 : $cpu_name"
    echo "Temperature          : $cpu_temp"
    echo "Cores                : $cpu_cores"
    echo "CPU Governor         : $cpu_gov"
    echo "CPU Driver           : $cpu_driver"
    echo "Turbo Boost          : $turbo_boost"
    echo "AMD P-State Mode     : $amd_pstate_mode"
    echo "EPP Preference       : $epp_pref"
    echo "Clocksource          : $clocksource"
    echo
    echo "GPU"
    echo "......................"
    echo "Name                 : $gpu_name"
    echo "VRAM                 : $gpu_vram"
    echo "Driver               : $driver_version"
    echo "OpenGL               : $opengl_version"
    echo "Vulkan               : $vulkan_version"
    echo "AMDGPU Power State   : $gpu_level"
    echo
    echo "Misc"
    echo "......................"
    echo "MangoHud             : $mangohud_check"
    echo "Gamescope            : $gamescope_check"
    echo "Steam udev rules     : $steam_udev_rules"

}

# Template for DXVK and VKD3D-Proton Github issues
dxvk_template() {
    sys_info
    local proton_version
    local dxvk_version
    local vkd3d_proton_version
    local proton_location=$HOME/"Games/Steam/steamapps/common/Proton - Experimental"

    dxvk_version="Commit: $(cat "$proton_location/files/lib/wine/dxvk/version" | cut -b 2-8)"
    proton_version="proton-$(cat "$proton_location/version" | awk '{print $2}')"
    vkd3d_proton_version="Commit: $(cat "$proton_location/files/lib/wine/vkd3d-proton/version" | cut -b 2-8)"

    echo "### System Information"
    echo "- CPU            : $cpu_name"
    echo "- RAM            : $ram_qty"
    echo "- GPU            : $gpu_name - $gpu_vram"
    echo ""
    echo "- Kernel         : $kernel_version"
    echo "- Driver         : Mesa $driver_version"
    echo "- Wine           : $proton_version"
    echo "- DXVK           : $dxvk_version"
    echo "- VKD3D-Proton   : $vkd3d_proton_version"
}
