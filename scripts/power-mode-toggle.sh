#!/bin/bash
# 机械革命无界14 Pro 原生 KDE OSD 功耗管理与能耗策略联动脚本
# 100% 队列顺序响应，支持 English/中文自适应
# 联动控制：CPU功耗墙、屏幕刷新率(120Hz<->60Hz)、PCIe ASPM、音频省电

exec 200>/run/lock/wujie_power.lock
flock -w 1 200 || exit 0

NEW_MODE=$(/usr/local/bin/ec-power-state 2>/dev/null)
[ -z "$NEW_MODE" ] && exit 0

# 检测是否接入交流电源 (1 = 插电, 0 = 电池)
AC_ONLINE=0
for ac in /sys/class/power_supply/{ACAD,ADP1,AC}/online; do
    if [ -f "$ac" ]; then
        AC_ONLINE=$(cat "$ac" 2>/dev/null || echo 0)
        break
    fi
done

# 检测图形会话用户语言偏好
USER_LANG="en"
if [ -S "/run/user/1000/bus" ]; then
    SYS_LANG=$(runuser -u yangyihua -- env | grep -E "^(LANG|LANGUAGE)=" | head -n1 | cut -d= -f2)
    [[ "$SYS_LANG" =~ ^zh ]] && USER_LANG="zh"
fi

# 获取当前活动 Wayland Display
WL_DISP=""
if [ -S "/run/user/1000/bus" ]; then
    WL_DISP=$(ls /run/user/1000/wayland-* 2>/dev/null | head -n1 | xargs -n1 basename 2>/dev/null)
    [ -z "$WL_DISP" ] && WL_DISP="wayland-0"
fi

if [ "$NEW_MODE" = "2" ]; then
    # ==============================================================
    # 平板级超低功耗模式 (Tablet Mode: 6W DSDT, 60Hz, powersave ASPM)
    # ==============================================================
    PROFILE="power-saver"
    ICON="battery-low"
    if [ "$USER_LANG" = "zh" ]; then
        MSG="🌿 平板超低功耗 (6W 静音 • 60Hz • 12h+)"
    else
        MSG="🌿 Tablet Mode (6W Silent • 60Hz • 12h+)"
    fi

    # 1. 屏幕降频至 60Hz
    if [ -n "$WL_DISP" ]; then
        runuser -u yangyihua -- env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY="$WL_DISP" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" \
            kscreen-doctor output.eDP-1.mode.2880x1800@60 2>/dev/null >/dev/null &
    fi

    # 2. PCIe ASPM 总线开启标准安全节能 (powersave)
    [ -f /sys/module/pcie_aspm/parameters/policy ] && echo powersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null

    # 3. 音频总线芯片开启自动休眠
    [ -f /sys/module/snd_hda_intel/parameters/power_save ] && echo 1 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null

else
    # ==============================================================
    # 正常模式 (Normal Mode: 插电54W/电池35W, 120Hz高刷, 默认ASPM)
    # ==============================================================
    PROFILE="balanced"
    ICON="battery-charging"
    if [ "$AC_ONLINE" = "1" ]; then
        if [ "$USER_LANG" = "zh" ]; then
            MSG="⚡ 正常模式 (插电 54W 自动 • 120Hz)"
        else
            MSG="⚡ Normal Mode (54W AC Auto • 120Hz)"
        fi
    else
        if [ "$USER_LANG" = "zh" ]; then
            MSG="⚡ 正常模式 (电池 35W 自动 • 120Hz)"
        else
            MSG="⚡ Normal Mode (35W Batt Auto • 120Hz)"
        fi
    fi

    # 1. 屏幕恢复 120Hz 高刷
    if [ -n "$WL_DISP" ]; then
        runuser -u yangyihua -- env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY="$WL_DISP" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" \
            kscreen-doctor output.eDP-1.mode.2880x1800@120 2>/dev/null >/dev/null &
    fi

    # 2. PCIe ASPM 恢复默认策略 (default)
    [ -f /sys/module/pcie_aspm/parameters/policy ] && echo default > /sys/module/pcie_aspm/parameters/policy 2>/dev/null

fi

# 确保全局 cpufreq boost 启用，以便 power-profiles-daemon 正常管理 amd_pstate
[ -f /sys/devices/system/cpu/cpufreq/boost ] && echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null

# 同步 Linux 内核与 AMD PMF 电源管理 (power-profiles-daemon 会自动管理 EPP 与调频)
powerprofilesctl set "$PROFILE" 2>/dev/null

# 触发 KDE 原生居中硬件级 OSD
if [ -S "/run/user/1000/bus" ]; then
    runuser -u yangyihua -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" \
        gdbus call --session \
        --dest org.kde.plasmashell \
        --object-path /org/kde/osdService \
        --method org.kde.osdService.showText "$ICON" "$MSG" 2>/dev/null >/dev/null
fi
