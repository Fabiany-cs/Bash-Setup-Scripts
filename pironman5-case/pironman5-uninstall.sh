#!/bin/bash
# =============================================================
# uninstall-pironman5.sh
# Removes all software installed by the SunFounder Pironman 5
# installer — service, virtual environment, bin, influxdb,
# device tree overlay, and cloned repo folder.
#
# This does NOT affect your OS, personal files, or networking.
# It only removes what the pironman5 installer put there.
#
# Usage: sudo bash uninstall-pironman5.sh
# =============================================================

set -e

# --- COLOR CODES ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()    { echo -e "\n${CYAN}==>${NC} $1"; }
# "|| true" after a remove command means "if this fails, keep going"
# Some items may not exist if the install was partial — that's fine
print_skipped() { echo -e "${YELLOW}[SKIP]${NC} $1 not found — skipping"; }

# --- CHECK: must be run as root ---
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script with sudo: sudo bash uninstall-pironman5.sh"
    exit 1
fi

# ============================================================
# HEADER
# ============================================================
clear
echo ""
echo "================================================"
echo "   Pironman 5 — Uninstall Script"
echo "================================================"
echo ""
echo -e "  ${YELLOW}Tip: Press Ctrl+C at any time to quit${NC}"
echo "================================================"
echo ""
echo "  This script will remove:"
echo "    - The pironman5 systemd service"
echo "    - The /opt/pironman5 virtual environment"
echo "    - The pironman5 bin command"
echo "    - influxdb (installed by pironman5)"
echo "    - The device tree overlay"
echo "    - The cloned repo folder in your home directory"
echo ""
echo -e "  ${GREEN}Your OS, files, and network settings are untouched.${NC}"
echo ""

# ============================================================
# MODEL SELECTION
# Each model has slightly different service names, opt paths,
# bin names, and repo folders — we set them all here so the
# rest of the script stays clean and model-agnostic.
# ============================================================
echo "  Which Pironman 5 model are you removing?"
echo -e "  Not sure? Visit: ${CYAN}https://docs.sunfounder.com/projects/pironman5/en/latest/index.html${NC}"
echo ""
echo "    1) Pironman 5          — single NVMe, aluminum case"
echo "    2) Pironman 5 MAX      — dual NVMe, black case, RGB tower fan"
echo "    3) Pironman 5 Mini     — compact case, single fan"
echo "    4) Pironman 5 Pro Max  — dual NVMe, 4.3\" touchscreen, camera, audio"
echo ""

while true; do
    read -r -p "Enter model number (1-4): " MODEL_NUM
    case "$MODEL_NUM" in
        1)
            MODEL_NAME="Pironman 5"
            SERVICE_NAME="pironman5"
            OPT_DIR="/opt/pironman5"
            BIN_FILE="/usr/local/bin/pironman5"
            REPO_DIR="pironman5"
            DTBO_FILE="sunfounder-pironman5.dtbo"
            break
            ;;
        2)
            MODEL_NAME="Pironman 5 MAX"
            SERVICE_NAME="pironman5"
            OPT_DIR="/opt/pironman5"
            BIN_FILE="/usr/local/bin/pironman5"
            REPO_DIR="pironman5-max"
            DTBO_FILE="sunfounder-pironman5.dtbo"
            break
            ;;
        3)
            MODEL_NAME="Pironman 5 Mini"
            SERVICE_NAME="pironman5-mini"
            OPT_DIR="/opt/pironman5-mini"
            BIN_FILE="/usr/local/bin/pironman5-mini"
            REPO_DIR="pironman5-mini"
            DTBO_FILE="sunfounder-pironman5mini.dtbo"
            break
            ;;
        4)
            MODEL_NAME="Pironman 5 Pro Max"
            SERVICE_NAME="pironman5-pro-max"
            OPT_DIR="/opt/pironman5-pro-max"
            BIN_FILE="/usr/local/bin/pironman5-pro-max"
            REPO_DIR="pironman5-pro-max"
            DTBO_FILE="sunfounder-pironman5promax.dtbo"
            break
            ;;
        *)
            print_error "Invalid selection — enter a number between 1 and 4"
            ;;
    esac
done

echo ""
print_info "Model selected: ${YELLOW}${MODEL_NAME}${NC}"
echo ""

# ============================================================
# CONFIRMATION — show exactly what will be deleted
# ============================================================
echo "  The following will be removed:"
echo "    - systemd service:  ${SERVICE_NAME}.service"
echo "    - virtual env:      ${OPT_DIR}"
echo "    - bin command:      ${BIN_FILE}"
echo "    - apt package:      influxdb"
echo "    - device overlay:   /boot/overlays/${DTBO_FILE}"
echo "    - repo folder:      ~/${REPO_DIR}"
echo ""
read -r -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]; then
    print_warning "Uninstall cancelled."
    exit 0
fi
echo ""

# ============================================================
# STEP 1 — STOP AND DISABLE THE SERVICE
# ============================================================
print_step "Step 1 of 5 — Stopping and disabling the service"

# Check if the service exists before trying to stop it
# "systemctl list-units" returns 0 if found, non-zero if not
if systemctl list-units --full --all | grep -q "${SERVICE_NAME}.service"; then
    systemctl stop "${SERVICE_NAME}.service" || true
    systemctl disable "${SERVICE_NAME}.service" || true
    print_info "Service stopped and disabled."
else
    print_skipped "${SERVICE_NAME}.service"
fi

# Remove the service file itself
# It may be in /usr/lib/systemd/system/ or /lib/systemd/system/
for SERVICE_PATH in \
    "/usr/lib/systemd/system/${SERVICE_NAME}.service" \
    "/lib/systemd/system/${SERVICE_NAME}.service" \
    "/etc/systemd/system/${SERVICE_NAME}.service"; do
    if [ -f "$SERVICE_PATH" ]; then
        rm -f "$SERVICE_PATH"
        print_info "Removed: $SERVICE_PATH"
    fi
done

# Tell systemd to re-read its service list now that we removed the file
systemctl daemon-reload
print_info "Systemd reloaded."

# ============================================================
# STEP 2 — REMOVE THE VIRTUAL ENVIRONMENT AND BIN
# ============================================================
print_step "Step 2 of 5 — Removing virtual environment and bin command"

if [ -d "$OPT_DIR" ]; then
    rm -rf "$OPT_DIR"
    print_info "Removed: $OPT_DIR"
else
    print_skipped "$OPT_DIR"
fi

if [ -f "$BIN_FILE" ]; then
    rm -f "$BIN_FILE"
    print_info "Removed: $BIN_FILE"
else
    print_skipped "$BIN_FILE"
fi

# ============================================================
# STEP 3 — REMOVE INFLUXDB
# ============================================================
print_step "Step 3 of 5 — Removing influxdb"

# Check if influxdb is installed before trying to remove it
if dpkg -l | grep -q "^ii.*influxdb"; then
    apt purge influxdb -y
    apt autoremove -y
    print_info "influxdb removed."
else
    print_skipped "influxdb"
fi

# ============================================================
# STEP 4 — REMOVE DEVICE TREE OVERLAY
# ============================================================
print_step "Step 4 of 5 — Removing device tree overlay"

DTBO_PATH="/boot/overlays/${DTBO_FILE}"
if [ -f "$DTBO_PATH" ]; then
    rm -f "$DTBO_PATH"
    print_info "Removed: $DTBO_PATH"
else
    # Also check the newer Raspberry Pi OS boot path
    DTBO_PATH_ALT="/boot/firmware/overlays/${DTBO_FILE}"
    if [ -f "$DTBO_PATH_ALT" ]; then
        rm -f "$DTBO_PATH_ALT"
        print_info "Removed: $DTBO_PATH_ALT"
    else
        print_skipped "$DTBO_FILE"
    fi
fi

# ============================================================
# STEP 5 — REMOVE THE CLONED REPO FOLDER
# ============================================================
print_step "Step 5 of 5 — Removing cloned repo folder"

REPO_PATH="$HOME/${REPO_DIR}"
if [ -d "$REPO_PATH" ]; then
    rm -rf "$REPO_PATH"
    print_info "Removed: $REPO_PATH"
else
    print_skipped "~/${REPO_DIR}"
fi

# ============================================================
# DONE
# ============================================================
echo ""
echo "================================================"
echo -e "  ${GREEN}Uninstall complete!${NC}"
echo "================================================"
echo ""
echo "  Everything installed by the pironman5 setup"
echo "  script has been removed."
echo ""
echo "  To reinstall at any time, run:"
echo -e "    ${CYAN}sudo bash setup-pironman5.sh${NC}"
echo ""

read -r -p "Reboot now to finalize removal? (yes/no): " REBOOT_ANSWER

if [[ "$REBOOT_ANSWER" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]; then
    print_info "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    sudo reboot now
else
    print_warning "Reboot skipped. Run 'sudo reboot' when ready."
fi
