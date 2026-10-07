#!/bin/bash
# ==============================================================================
# Mechrevo Wujie 14 Pro (AMD Ryzen 7 8845HS) - Linux Hardware Enhancement Suite
# Automated Installation Script
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root (e.g. sudo ./install.sh)"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KVER="$(uname -r)"

echo "======================================================================"
echo " Mechrevo Wujie 14 Pro Linux Suite Installation"
echo " Kernel Target: ${KVER}"
echo "======================================================================"

# 1. Install prerequisites
echo "[1/6] Installing build and runtime dependencies..."
apt-get update -y
apt-get install -y build-essential linux-headers-"${KVER}" acpid acpica-tools python3-gi gir1.2-glib-2.0 zstd cpio

# 2. Build and install ec-power-state utility
echo "[2/6] Compiling ec-power-state utility..."
gcc -O2 "${ROOT_DIR}/scripts/ec-power-state.c" -o /usr/local/bin/ec-power-state
chmod 755 /usr/local/bin/ec-power-state

# 3. Install ACPI event handlers
echo "[3/6] Installing ACPI event handlers and OSD scripts..."
cp "${ROOT_DIR}/scripts/power-mode-toggle.sh" /etc/acpi/power-mode-toggle.sh
chmod 755 /etc/acpi/power-mode-toggle.sh
cp "${ROOT_DIR}/scripts/wujie-power-toggle" /etc/acpi/events/wujie-power-toggle
systemctl restart acpid

# 4. Build and install wujie_acpi kernel driver
echo "[4/6] Building and installing wujie_acpi kernel driver..."
cd "${ROOT_DIR}/kernel/wujie_acpi"
make -C "/lib/modules/${KVER}/build" M="${ROOT_DIR}/kernel/wujie_acpi" modules
mkdir -p "/lib/modules/${KVER}/updates/drivers/platform/x86"
cp "${ROOT_DIR}/kernel/wujie_acpi/wujie_acpi.ko" "/lib/modules/${KVER}/updates/drivers/platform/x86/"
zstd -f --rm "/lib/modules/${KVER}/updates/drivers/platform/x86/wujie_acpi.ko"
depmod -a "${KVER}"
echo "wujie_acpi" > /etc/modules-load.d/wujie_acpi.conf
modprobe wujie_acpi || insmod "/lib/modules/${KVER}/updates/drivers/platform/x86/wujie_acpi.ko.zst" || true

# 5. Install wujie-power-sync system daemon
echo "[5/6] Installing power synchronization daemon..."
cp "${ROOT_DIR}/daemon/wujie-power-sync" /usr/local/bin/wujie-power-sync
chmod 755 /usr/local/bin/wujie-power-sync
cp "${ROOT_DIR}/daemon/wujie-power-sync.service" /etc/systemd/system/wujie-power-sync.service
systemctl daemon-reload
systemctl enable --now wujie-power-sync.service

# 6. Build and deploy ACPI DSDT override
echo "[6/6] Compiling ACPI DSDT Revision 7 override..."
bash "${ROOT_DIR}/acpi/build_acpi_override.sh"

echo ""
echo "======================================================================"
echo " Installation completed successfully!"
echo " A reboot is recommended to load the DSDT early initrd table override."
echo "======================================================================"
