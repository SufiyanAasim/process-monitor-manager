#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ALERT_THRESHOLD="${PMM_HIGH_THRESHOLD:-50}"

while true; do
    ACTION=$(zenity --list --title="Process Manager GUI" \
        --text="Select an action to perform:" \
        --radiolist \
        --column="Select" --column="Action" \
        TRUE "Show Process Info" \
        FALSE "Search a Process" \
        FALSE "Show Alerts (High CPU/MEM)" \
        FALSE "Live Dashboard" \
        FALSE "Export to CSV" \
        FALSE "Kill a Process" \
        FALSE "Suspend a Process" \
        FALSE "Resume a Process" \
        FALSE "Exit")

    case "$ACTION" in
        "Show Process Info")
            TEMP_FILE=$(mktemp)
            ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 20 > "$TEMP_FILE"

            if [[ -s "$TEMP_FILE" ]]; then
                zenity --text-info --title="Top 20 Processes" --filename="$TEMP_FILE" --width=800 --height=400
            else
                zenity --error --text="Could not fetch process info."
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Search a Process")
            QUERY=$(zenity --entry --title="Search Process" --text="Enter process name or PID:")

            if [[ -z "$QUERY" ]]; then
                continue  # User clicked cancel or entered nothing
            fi

            TEMP_FILE=$(mktemp)
            {
                ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 1
                ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | grep -i -- "$QUERY"
            } > "$TEMP_FILE"

            if [[ $(wc -l < "$TEMP_FILE") -le 1 ]]; then
                zenity --error --text="No matching processes found for '$QUERY'."
            else
                zenity --text-info --title="Search Results: $QUERY" --filename="$TEMP_FILE" --width=800 --height=400
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Show Alerts (High CPU/MEM)")
            TEMP_FILE=$(mktemp)
            {
                ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 1
                ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | awk -v t="$ALERT_THRESHOLD" '$(NF)+0 >= t || $(NF-1)+0 >= t'
            } > "$TEMP_FILE"

            if [[ $(wc -l < "$TEMP_FILE") -le 1 ]]; then
                zenity --info --text="No processes currently exceed ${ALERT_THRESHOLD}% CPU or MEM."
            else
                zenity --text-info --title="High CPU/MEM Alerts" --filename="$TEMP_FILE" --width=800 --height=400
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Live Dashboard")
            if ! command -v python3 &>/dev/null; then
                zenity --error --text="python3 is required for the live dashboard.\nInstall it with: sudo apt install python3"
                continue
            fi

            TERMINAL=""
            for candidate in x-terminal-emulator gnome-terminal konsole xfce4-terminal xterm; do
                if command -v "$candidate" &>/dev/null; then
                    TERMINAL="$candidate"
                    break
                fi
            done

            if [[ -z "$TERMINAL" ]]; then
                zenity --error --text="No terminal emulator found to launch the dashboard.\nInstall one with: sudo apt install xterm -y\nOr run manually: python3 \"$SCRIPT_DIR/modules/dashboard.py\""
                continue
            fi

            "$TERMINAL" -e python3 "$SCRIPT_DIR/modules/dashboard.py" &
            ;;

        "Export to CSV")
            OUTFILE="process_snapshot_$(date +%Y%m%d_%H%M%S).csv"
            {
                echo "PID,PPID,CMD,%MEM,%CPU"
                ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | tail -n +2 | awk '{
                    cmd = ""
                    for (i = 3; i <= NF - 2; i++) cmd = cmd (i > 3 ? " " : "") $i
                    gsub(/"/, "\"\"", cmd)
                    printf "%s,%s,\"%s\",%s,%s\n", $1, $2, cmd, $(NF - 1), $NF
                }'
            } > "$OUTFILE"

            zenity --info --text="Exported current process snapshot to:\n$(pwd)/$OUTFILE"
            ;;

        "Kill a Process")
            PROCESS_LIST=$(ps -eo pid,comm --sort=-%cpu | awk 'NR>1 {print $1 ":" $2}' | head -n 20)

            PID=$(zenity --list --title="Kill Process" \
                --text="Select a process to kill" \
                --column="PID:Command" \
                $(echo "$PROCESS_LIST"))  # automatically expanded into list

            if [[ -z "$PID" ]]; then
                continue  # User clicked cancel or back
            fi

            PID_TO_KILL=$(echo "$PID" | cut -d':' -f1)

            kill "$PID_TO_KILL" && \
            zenity --info --text="Process $PID_TO_KILL killed." || \
            zenity --error --text="Failed to kill process $PID_TO_KILL."
            ;;

        "Suspend a Process")
            PID=$(zenity --entry --title="Suspend Process" --text="Enter PID to suspend:")

            if [[ -z "$PID" ]]; then continue; fi

            kill -STOP "$PID" && \
            zenity --info --text="Process $PID suspended." || \
            zenity --error --text="Failed to suspend process $PID."
            ;;

        "Resume a Process")
            PID=$(zenity --entry --title="Resume Process" --text="Enter PID to resume:")

            if [[ -z "$PID" ]]; then continue; fi

            kill -CONT "$PID" && \
            zenity --info --text="Process $PID resumed." || \
            zenity --error --text="Failed to resume process $PID."
            ;;

        "Exit")
            break
            ;;

        *)
            # Cancel or no selection
            continue
            ;;
    esac
done
