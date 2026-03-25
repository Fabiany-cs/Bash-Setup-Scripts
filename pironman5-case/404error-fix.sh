#!/bin/bash
# Use bash shell to execute this script

set -euo pipefail
# -e  → Exit immediately if ANY command fails (prevents continuing in a broken state)
# -u  → Treat unset variables as an error (avoids typos like $DAT_DIR)
# -o pipefail → If any command in a pipeline fails, the whole pipeline fails
# (Example: cmd1 | cmd2 → fails if cmd1 OR cmd2 fails)

SERVICE="pironman5.service"
# Name of the systemd service we are managing

DATA_DIR="/var/lib/influxdb/data/pironman5"
# Path where InfluxDB stores Pironman5 data

WAL_DIR="/var/lib/influxdb/wal/pironman5"
# WAL = Write-Ahead Log (temporary write buffer used by InfluxDB)

echo "========================================"
echo " Resetting Pironman5 InfluxDB 404 Error "
echo "========================================"
echo

echo "This script will:"
echo "1. Stop $SERVICE"
echo "2. Remove old InfluxDB data for Pironman5"
echo "3. Start $SERVICE again"
echo

read -rp "Continue? [y/N]: " confirm
# -r → Prevents backslash escaping (safer input handling)
# -p → Displays prompt inline

case "$confirm" in
  [yY][eE][sS]|[yY]) ;;
  # Accepts: y, Y, yes, YES, Yes, etc.

  *) echo "Cancelled."; exit 0 ;;
  # Anything else → exit safely without running the script
esac

echo
echo "[1/3] Stopping $SERVICE..."
sudo systemctl stop "$SERVICE"
# Stops the Pironman5 service to prevent file corruption
# systemctl = systemd service manager (modern replacement for "service")

echo "[2/3] Removing old InfluxDB data..."

if [ -d "$DATA_DIR" ]; then
# -d checks if directory exists

  sudo rm -rf "$DATA_DIR"
  # rm  = remove
  # -r  = recursive (delete folders + contents)
  # -f  = force (no prompts, ignore missing files)

  echo "Removed: $DATA_DIR"
else
  echo "Skipped: $DATA_DIR not found"
fi

if [ -d "$WAL_DIR" ]; then
  sudo rm -rf "$WAL_DIR"
  echo "Removed: $WAL_DIR"
else
  echo "Skipped: $WAL_DIR not found"
fi

echo "[3/3] Starting $SERVICE..."
sudo systemctl start "$SERVICE"
# Starts the service again (it will recreate fresh InfluxDB data)

echo
echo "Checking service status..."

sudo systemctl --no-pager --full status "$SERVICE" || true
# --no-pager → prints output directly (no "less" scrolling view)
# --full → shows full logs (no truncation)
# || true → prevents script from exiting if this command fails
# (important because set -e would otherwise stop the script here)

echo
echo "Done. Pironman5 has been reset."