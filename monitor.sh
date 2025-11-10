#!/bin/bash

# =====================
# Process Monitor & Manager - Entry Script
# =====================

# Check for GUI Flag
if [[ "$1" == "--gui" ]]; then
    echo "Launching GUI mode..."
    bash ./monitor_gui.sh
    exit 0
fi

# CLI Mode Starts Here
source modules/monitor_module.sh
source modules/manage_module.sh
source modules/input_module.sh

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
    echo "6. Exit"
    echo "============================"
}

# Main Loop
while true; do
    show_menu
    read -rp "Enter your choice: " choice
    handle_user_input "$choice"
done
