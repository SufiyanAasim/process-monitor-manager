#!/bin/bash
# Installs system dependencies and makes the entry points/modules executable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Installing dependencies (procps, psmisc, tree, zenity)..."
sudo apt update
sudo apt install -y procps psmisc tree zenity

echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR"/monitor.sh "$SCRIPT_DIR"/monitor_gui.sh "$SCRIPT_DIR"/modules/*.sh "$SCRIPT_DIR"/scripts/*.sh "$SCRIPT_DIR"/tests/*.sh

echo "Done. Run ./monitor.sh or ./monitor.sh --gui to start."
