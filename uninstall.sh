#!/bin/bash
# ==============================================================================
# Mechrevo Wujie 14 Pro - Linux Hardware Enhancement Suite
# Uninstallation Script
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root (e.g. sudo ./uninstall.sh)"
    exit 1
fi

echo "==> Stopping and disabling wujie-power-sync service..."
systemctl stop wujie-power-sync.service 2>/dev/null || true
systemctl disable wujie-power-sync.service 2>/dev/null || true
rm -f /etc/systemd/system/wujie-power-sync.service
systemctl daemon-reload

echo "==> Removing daemon and utilities..."
rm -f /usr/local/bin/wujie-power-sync
rm -f /usr/local/bin/ec-power-state

echo "==> Removing ACPI event scripts..."
rm -f /etc/acpi/power-mode-toggle.sh
rm -f /etc/acpi/events/wujie-power-toggle
systemctl restart acpid 2>/dev/null || true

echo "==> Unloading and removing wujie_acpi kernel driver..."
rmmod wujie_acpi 2>/dev/null || true
rm -f /etc/modules-load.d/wujie_acpi.conf
rm -f /lib/modules/$(uname -r)/updates/drivers/platform/x86/wujie_acpi.ko*
depmod -a

echo "==> Removing DSDT ACPI override..."
rm -f /boot/acpi_override

echo "==> Uninstallation complete."
