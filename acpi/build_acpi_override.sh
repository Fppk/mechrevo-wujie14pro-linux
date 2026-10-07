#!/bin/bash
# Mechrevo Wujie 14 Pro - ACPI DSDT Override Generator
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSL_FILE="${SCRIPT_DIR}/dsdt_revision7.dsl"
BUILD_DIR="${SCRIPT_DIR}/build"
DEST="/boot/acpi_override"

echo "==> Compiling ${DSL_FILE} with iasl..."
mkdir -p "${BUILD_DIR}/kernel/firmware/acpi"
iasl -tc -p "${BUILD_DIR}/dsdt" "${DSL_FILE}"

cp "${BUILD_DIR}/dsdt.aml" "${BUILD_DIR}/kernel/firmware/acpi/dsdt.aml"

echo "==> Packaging into uncompressed CPIO archive..."
cd "${BUILD_DIR}"
find kernel | cpio -H newc --create > "${BUILD_DIR}/acpi_override"

echo "==> Installing to ${DEST}..."
sudo cp "${BUILD_DIR}/acpi_override" "${DEST}"
sudo chmod 644 "${DEST}"

echo "==> Verifying archive..."
cpio -tv < "${DEST}"

echo "==> Successfully installed ${DEST}."
