#!/bin/bash

handle_user_input() {
    case "$1" in
        1) show_process_info ;;
        2) kill_process ;;
        3) suspend_process ;;
        4) resume_process ;;
        5) show_process_tree ;;
        6) search_process ;;
        7) show_alerts ;;
        8) launch_dashboard ;;
        9) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option!" ;;
    esac
}
