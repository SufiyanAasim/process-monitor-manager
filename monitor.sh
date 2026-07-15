#!/bin/bash

# =====================
# Process Monitor & Manager - Entry Script
# =====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for GUI Flag
if [[ "$1" == "--gui" ]]; then
    echo "Launching GUI mode..."
    bash "$SCRIPT_DIR/monitor_gui.sh"
    exit 0
fi

# CLI Mode Starts Here
source "$SCRIPT_DIR/modules/monitor_module.sh"
source "$SCRIPT_DIR/modules/manage_module.sh"
source "$SCRIPT_DIR/modules/input_module.sh"

# CLI Menu Function
show_menu() {
    echo ""
    echo "============================"
    echo " Process Monitor & Manager "
    echo "============================"
    echo "1. Show Process Info"
    echo "2. Kill Process"
    echo "3. Suspend Process"
    echo "4. Resume Process"
    echo "5. Show Process Tree"
    echo "6. Search Process"
    echo "7. Show Alerts (High CPU/MEM)"
    echo "8. Live Dashboard"
    echo "9. Export to CSV"
    echo "10. Credits"
    echo "11. Exit"
    echo "============================"
}

# Main Loop
while true; do
    show_menu
    if ! read -rp "Enter your choice: " choice; then
        echo ""
        echo "Exiting..."
        exit 0
    fi
    handle_user_input "$choice"
done
