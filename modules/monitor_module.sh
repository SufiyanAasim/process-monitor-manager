#!/bin/bash
# ==============================================================================
# Process Monitoring & Reporting Module (modules/monitor_module.sh)
# @author: Sufiyan Aasim (@SufiyanAasim) <sufiyanaasim@outlook.com>
# Responsibilities: Process inspection, searching, alerting, tree views, CSV export,
# and threshold-based CPU/MEM colorization.
# ==============================================================================

# Config file precedence: explicit environment variable > config file > default.
# Capture any env vars the caller already set before the config file can touch them.
_ENV_PMM_HIGH_THRESHOLD="${PMM_HIGH_THRESHOLD:-}"
_ENV_PMM_MED_THRESHOLD="${PMM_MED_THRESHOLD:-}"

readonly PMM_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/process-monitor-manager/config"
if [[ -f "$PMM_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PMM_CONFIG_FILE"
fi

[[ -n "$_ENV_PMM_HIGH_THRESHOLD" ]] && PMM_HIGH_THRESHOLD="$_ENV_PMM_HIGH_THRESHOLD"
[[ -n "$_ENV_PMM_MED_THRESHOLD" ]] && PMM_MED_THRESHOLD="$_ENV_PMM_MED_THRESHOLD"

readonly HIGH_THRESHOLD="${PMM_HIGH_THRESHOLD:-50}"
readonly MED_THRESHOLD="${PMM_MED_THRESHOLD:-20}"

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
    cpu=${cpu//[^0-9]/}
    cpu=${cpu:-0}

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
    matches=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | grep -iF -- "$query")

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

# Writes a CSV snapshot of the current process list to the current directory.
# On success prints the filename and returns 0; on failure (an unwritable
# directory, most likely) prints nothing and returns 1 — callers must check,
# or they'll report success for a file that was never written.
# Only the filename is printed so both the CLI and the GUI can word their own
# message around it.
export_csv() {
    local outfile
    outfile="process_snapshot_$(date +%Y%m%d_%H%M%S).csv"

    # Deliberately an if/else rather than `if ! { ... } > "$outfile"`: when the
    # redirection itself fails, bash returns 1 for the whole construct and the
    # `!` does not invert it, so the negated form silently never fires.
    if {
        echo "PID,PPID,CMD,%MEM,%CPU"
        ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | awk '{
            cmd = ""
            for (i = 3; i <= NF - 2; i++) cmd = cmd (i > 3 ? " " : "") $i
            gsub(/"/, "\"\"", cmd)
            printf "%s,%s,\"%s\",%s,%s\n", $1, $2, cmd, $(NF - 1), $NF
        }'
    } 2>/dev/null > "$outfile"; then
        echo "$outfile"
    else
        rm -f "$outfile" 2>/dev/null
        return 1
    fi
}

show_credits() {
    echo ""
    echo "============================"
    echo " Process Monitor & Manager "
    echo "============================"
    echo ""
    echo "Sufiyan Aasim - Author & Maintainer"
    echo "  GitHub:  https://github.com/SufiyanAasim"
    echo "  Contact: sufiyanaasim@outlook.com"
    echo ""
    echo "Muhammad Taha Siddiqui - Contributor (process control)"
    echo "  GitHub:  https://github.com/13eeCoder"
    echo "  Contact: tahasiddiqui2100@gmail.com"
    echo ""
    echo "Repository: https://github.com/SufiyanAasim/process-monitor-manager"
}

launch_dashboard() {
    if ! command -v python3 &>/dev/null; then
        echo "python3 is required for the live dashboard. Install it with: sudo apt install python3"
        return
    fi
    python3 "$(dirname "${BASH_SOURCE[0]}")/dashboard.py"
}
