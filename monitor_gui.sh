#!/bin/bash

while true; do
    ACTION=$(zenity --list --title="Process Manager GUI" \
        --text="Select an action to perform:" \
        --radiolist \
        --column="Select" --column="Action" \
        TRUE "Show Process Info" \
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
