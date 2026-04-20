#!/bin/bash

readonly HIGH_THRESHOLD=50
readonly MED_THRESHOLD=20

readonly COLOR_RED=$'\033[1;31m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_RESET=$'\033[0m'

# Colors a ps output line by its %CPU value (last whitespace-separated field)
colorize_line() {
    local line="$1"
    local cpu
    cpu=$(awk '{print $NF}' <<< "$line")
    cpu=${cpu%%.*}

    if (( cpu >= HIGH_THRESHOLD )); then
        printf '%s%s%s\n' "$COLOR_RED" "$line" "$COLOR_RESET"
    elif (( cpu >= MED_THRESHOLD )); then
        printf '%s%s%s\n' "$COLOR_YELLOW" "$line" "$COLOR_RESET"
    else
        printf '%s%s%s\n' "$COLOR_GREEN" "$line" "$COLOR_RESET"
    fi
}

show_process_info() {
    echo -e "\nPID\tPPID\tCMD\t\t%MEM\t%CPU"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | head -15 | while IFS= read -r line; do
        colorize_line "$line"
    done
}

show_process_tree() {
    echo -e "\nProcess Hierarchy (Tree View):"
    pstree -p
}

search_process() {
    read -rp "Enter process name or PID to search: " query
    if [[ -z "$query" ]]; then
        echo "Search query cannot be empty."
        return
    fi

    local matches
    matches=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | grep -i -- "$query")

    if [[ -z "$matches" ]]; then
        echo "No matching processes found for '$query'."
        return
    fi

    echo -e "\nPID\tPPID\tCMD\t\t%MEM\t%CPU"
    while IFS= read -r line; do
        colorize_line "$line"
    done <<< "$matches"
}

show_alerts() {
    local alerts
    alerts=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | awk -v t="$HIGH_THRESHOLD" '$(NF)+0 >= t || $(NF-1)+0 >= t')

    if [[ -z "$alerts" ]]; then
        echo -e "\nNo processes currently exceed the ${HIGH_THRESHOLD}% CPU/MEM threshold."
        return
    fi

    echo -e "\nProcesses above ${HIGH_THRESHOLD}% CPU or MEM:"
    echo -e "PID\tPPID\tCMD\t\t%MEM\t%CPU"
    while IFS= read -r line; do
        colorize_line "$line"
    done <<< "$alerts"
}

launch_dashboard() {
    if ! command -v python3 &>/dev/null; then
        echo "python3 is required for the live dashboard. Install it with: sudo apt install python3"
        return
    fi
    python3 "$(dirname "${BASH_SOURCE[0]}")/dashboard.py"
}
