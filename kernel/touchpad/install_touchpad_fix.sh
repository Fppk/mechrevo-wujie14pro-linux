#!/bin/bash
# Builds and installs patched hid-multitouch kernel module
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KVER="$(uname -r)"
KDIR="/lib/modules/${KVER}/build"
DEST_DIR="/lib/modules/${KVER}/updates/drivers/hid"

echo "==> Compiling patched hid-multitouch for kernel ${KVER}..."
cd "${SCRIPT_DIR}"
make -C "${KDIR}" M="${SCRIPT_DIR}" modules

echo "==> Installing module to ${DEST_DIR}..."
sudo mkdir -p "${DEST_DIR}"
sudo cp "${SCRIPT_DIR}/hid-multitouch.ko" "${DEST_DIR}/"
sudo zstd -f --rm "${DEST_DIR}/hid-multitouch.ko"
sudo depmod -a "${KVER}"

echo "==> Updating initramfs..."
sudo update-initramfs -u -k "${KVER}"

echo "==> Successfully installed patched hid-multitouch driver."
