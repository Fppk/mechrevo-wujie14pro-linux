# Mechrevo Wujie 14 Pro Linux Enhancement Suite

Comprehensive hardware-level Linux support package for the **Mechrevo Wujie 14 Pro** (AMD Ryzen 7 8845HS / Hawk Point platform).

This project resolves critical Linux hardware integration issues, implements an automated dual-state power architecture, establishes bidirectional desktop-to-firmware power synchronization, and integrates dynamic display and bus power management.

---

## Hardware Target

* **System Model**: Mechrevo Wujie 14 Pro (WUJIE14 Series-HPT / Motherboard BIOS: T140_HPT_V09)
* **Processor**: AMD Ryzen 7 8845HS (8 Cores / 16 Threads, Zen 4, TSMC 4nm FinFET, Radeon 780M)
* **Touchpad**: Hantick `HTIX5288:00` (I2C HID `0911:5288`)
* **Display**: Tianma `TL140ADXP24-0` (14.0", 2880x1800, 120Hz IPS LCD)
* **Battery**: 4S1P Li-ion Pack (AEC3166124-4S1P, 60 Wh design, ~15.0V nominal)
* **Wireless**: Intel Wi-Fi 6 AX200 (PCIe `01:00.0`)
* **Storage**: YMTC PC300 1TB NVMe SSD (PCIe `02:00.0`, DRAM-less)

---

## Core Features

### 1. Touchpad Button Lockup and Gesture Resolution
* **Problem**: Under Linux `hid-multitouch`, the `HTIX5288:00 0911:5288` I2C touchpad suffered from persistent left-click retention, mouse cursor freezes, and inadvertent two-finger scrolling transitions caused by missing touch-up packets from the hardware controller.
* **Resolution**:
  * Applied the `MT_CLS_WIN_8_FORCE_MULTI_INPUT_NSMU` driver class to `drivers/hid/hid-multitouch.c`.
  * Activated `MT_QUIRK_NOT_SEEN_MEANS_UP`, forcing contact slots to immediately release when unobserved in subsequent input frames.
  * Restored `Level, ActiveLow` ACPI interrupt signaling in the DSDT I2C descriptor table.

### 2. Dual-State Power Architecture (Normal vs. Tablet)
Replaces chaotic multi-state cycling with a deterministic, two-profile power state model:

| Operating Mode | AC Power Limit | Battery Power Limit | Display Rate | Bus ASPM | Target Scenario |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Normal Mode** | 54W Sustained / 65W Burst | 35W Sustained / 40W Burst | 2880x1800 @ 120Hz | `default` | Standard desktop workloads, coding, gaming |
| **Tablet Mode** | 6W Sustained / 10W Burst | 6W Sustained / 10W Burst | 2880x1800 @ 60Hz | `powersave` | Reading, note-taking, silent office, 12+ hr battery |

* **Automatic AC / Battery Detection**: In Normal Mode, the ACPI DSDT firmware dynamically switches between 54W (AC connected) and 35W (Battery connected) to safeguard the 4S battery cells from high-drain voltage drops.
* **Fn+F1 Single-Stroke Toggle**: Alternates strictly between Normal Mode and Tablet Mode with zero state ambiguity.

### 3. Subsystem Energy Optimization
* **Dynamic Display Refresh**: Dropping from 120Hz to 60Hz in Tablet Mode via `kscreen-doctor` eliminates ~1.3W of GPU display engine and TCON transceiver consumption without user intervention.
* **PCIe ASPM Policy**: Engages standard-compliant `powersave` ASPM on battery in Tablet Mode. Avoids aggressive `powersupersave` to protect DRAM-less NVMe SSDs from wake-up timeout resets while reclaiming ~0.3W of PCIe bus power.
* **Audio Runtime Power-Down**: Automatically engages `snd_hda_intel.power_save=1` on idle.

### 4. Bidirectional Desktop and Hardware Synchronization
* **The Challenge**: Linux desktop power profiles (`power-profiles-daemon`) traditionally control only kernel CPU governors and EPP preferences, remaining isolated from proprietary vendor Embedded Controller (EC) registers and AMD SMU power limits.
* **The Solution**:
  * Developed `wujie_acpi.ko`, a custom in-tree ACPI/WMI bridge kernel module exposing `/proc/wujie_mode`.
  * Invokes the vendor ACPI WMI method `\_SB.PCI0.WMID.WMAA(0xFB00, 0x0800, mode)` to trigger official DSDT power table programming.
  * Implemented `wujie-power-sync`, a systemd service monitoring `net.hadess.PowerProfiles` over D-Bus with anti-loop feedback detection. Changing profiles in the desktop system tray automatically programs the EC and AMD SMU; pressing `Fn+F1` automatically updates the system tray.

### 5. Native KDE Plasma Centered OSD HUD
* Dispatched through `org.kde.osdService.showText`, rendering centered hardware overlay notifications matching native KDE Plasma aesthetics.
* Eliminates notification center toast pollution and PAM authentication latency.
* Bilingual support (English and Chinese), automatically adapted from active desktop environment locale.

---

## Stress Test Benchmarks & Telemetry

Tested on actual hardware using `stress-ng --cpu 16` (100% all-core workload for 10 seconds continuous execution):

### Tablet Mode (Revision 7 DSDT, Battery Power, 28% Charge)

```text
Time   | Avg Freq    | CPU Pkg Power | Battery Drain | Die Temp | Fans (L/R)    | Hardware Profile
--------------------------------------------------------------------------------------------------
  1s   | 1397.3 MHz  |    10.01 W    |     6.84 W    |  39.1°C  | 2348 / 2246   | balanced(EC:2)
  2s   | 1397.3 MHz  |    10.00 W    |     6.84 W    |  39.8°C  | 2356 / 2143   | balanced(EC:2)
  3s   | 1472.5 MHz  |    10.00 W    |    10.51 W    |  40.0°C  | 2308 / 2239   | balanced(EC:2)
  4s   | 1397.3 MHz  |    10.02 W    |    10.51 W    |  40.2°C  | 2343 / 2145   | balanced(EC:2)
  5s   | 1397.3 MHz  |    10.03 W    |    10.54 W    |  40.4°C  | 2343 / 2241   | balanced(EC:2)
  6s   | 1470.7 MHz  |     9.98 W    |    10.54 W    |  40.6°C  | 2169 / 2255   | balanced(EC:2)
  7s   | 1456.2 MHz  |    10.02 W    |    10.57 W    |  40.8°C  | 2372 / 2209   | balanced(EC:2)
  8s   | 1461.2 MHz  |    10.02 W    |    10.57 W    |  40.9°C  | 2213 / 2248   | balanced(EC:2)
  9s   | 1537.2 MHz  |     9.98 W    |    10.58 W    |  40.9°C  | 2346 / 2257   | balanced(EC:2)
 10s   | 1193.5 MHz  |     9.34 W    |    10.55 W    |  41.0°C  | 2184 / 2109   | balanced(EC:2)
```

### Profile Performance Summary

| Metric | Normal Mode (Battery) | Tablet Mode (Battery) | Delta |
| :--- | :--- | :--- | :--- |
| **CPU Package Power** | 40.00 W (Locked) | **10.00 W (Locked)** | **-75.0%** |
| **All-Core Sustained Clock** | 4.07 GHz | **1.40 ~ 1.50 GHz** | High-efficiency band |
| **Total System Battery Drain** | 35.38 W ~ 45.0 W | **10.54 W** | **-70.2%** |
| **Full-Load Peak Temperature** | 86.6°C | **41.0°C** | **-45.6°C** |
| **Static Idle Battery Drain** | 6.5 W ~ 7.5 W | **3.8 W ~ 4.2 W** | Reaches 12.8+ hr endurance |

---

## Repository Structure

```text
.
├── acpi/
│   ├── build_acpi_override.sh       # Compiles DSDT and builds /boot/acpi_override CPIO
│   └── dsdt_revision7.dsl           # Custom ACPI DSDT with 6W/10W curves & touchpad fix
├── daemon/
│   ├── wujie-power-sync             # Bidirectional D-Bus synchronization daemon
│   └── wujie-power-sync.service     # Systemd service definition
├── kernel/
│   ├── touchpad/                    # Touchpad driver patches and build automation
│   │   ├── Makefile
│   │   ├── install_touchpad_fix.sh
│   │   └── patches/
│   └── wujie_acpi/                  # WMI/ACPI bridge kernel module (/proc/wujie_mode)
│       ├── Makefile
│       ├── wujie_acpi.c
│       └── wujie_acpi.conf
├── scripts/
│   ├── ec-power-state.c             # Direct MMIO status inspection utility
│   ├── power-mode-toggle.sh         # ACPI event dispatcher (Display, ASPM, OSD)
│   └── wujie-power-toggle           # acpid event rule definition
├── install.sh                       # Unified automated installation script
├── uninstall.sh                     # Complete uninstallation and clean-up script
├── LICENSE                          # MIT License
└── README.md
```

---

## Installation

### Prerequisites

* OS: Ubuntu 24.04 LTS / Debian 12 / Arch Linux / Fedora with Linux kernel >= 6.8
* Desktop Environment: KDE Plasma 6 (Wayland) recommended for native centered OSD HUD
* Dependencies: `build-essential`, `linux-headers-$(uname -r)`, `acpid`, `acpica-tools`, `python3-gi`, `cpio`, `zstd`

### One-Step Installation

Clone the repository and run the installation script:

```bash
git clone https://github.com/Fppk/mechrevo-wujie14pro-linux.git
cd mechrevo-wujie14pro-linux
sudo ./install.sh
```

### GRUB Configuration for ACPI Override

Verify that `/boot/acpi_override` is loaded prior to the default initrd in your bootloader.

For GRUB, verify `/etc/default/grub` contains:

```text
GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi_override"
```

Then update GRUB:

```bash
sudo update-grub
```

Reboot your system to apply early initrd table overrides.

---

## Verification

### 1. Verify ACPI DSDT Override
Run after reboot:
```bash
sudo dmesg | grep -i "Table Upgrade: override"
```
Expected output:
```text
ACPI: Table Upgrade: override [DSDT-INSYDE-EDK2    ]
```

### 2. Verify Touchpad Driver
```bash
dmesg | grep -i "multitouch"
```
Touch tracking slots will report clean idle states without sticking or synthetic dragging.

### 3. Verify Power Mode Synchronization
Check current hardware mode:
```bash
cat /proc/wujie_mode
```
* `2` = Tablet Mode (6W/10W, 60Hz display, powersave ASPM)
* `1` = Normal Mode on Battery (35W, 120Hz display, default ASPM)
* `0` = Normal Mode on AC (54W, 120Hz display, default ASPM)

Toggle using the physical keyboard shortcut:
* Press `Fn+F1`: The centered KDE OSD HUD will display the active mode, the internal display will switch refresh rate, and the system tray power icon will update synchronously.

Toggle using desktop GUI:
* Open system battery settings and select `Power-saver`: The screen switches to 60Hz and `/proc/wujie_mode` switches to `2`.
* Select `Balanced`: The screen switches to 120Hz and `/proc/wujie_mode` returns to `1` (or `0`).

---

## Uninstallation

To remove all kernel modules, services, and ACPI overrides:

```bash
sudo ./uninstall.sh
```

---

## License

This project is licensed under the [MIT License](LICENSE).
