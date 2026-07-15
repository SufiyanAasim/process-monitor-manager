#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/monitor_module.sh"

# icon.svg is tuned to stay legible at GTK's ~48px dialog-icon size;
# logo.svg is the detailed README artwork and is only a fallback here.
ICON_ARGS=()
for candidate in "$SCRIPT_DIR/assets/icon.svg" "$SCRIPT_DIR/assets/logo.svg"; do
    if [[ -f "$candidate" ]]; then
        ICON_ARGS=(--icon="$candidate")
        break
    fi
done

# Zenity parses --text as Pango markup by default, so any '&', '<' or '>' in
# interpolated content (a path, a search query) aborts the dialog. Everything
# that interpolates uses --no-markup; only the static Credits text opts in.
#
# --no-markup also turns off '\n' escape handling, so these dialogs must carry
# real newlines in the string rather than a literal backslash-n — which would
# otherwise render on screen verbatim.
readonly NO_MARKUP=(--no-markup)

# Builds a Zenity process picker and prints the selected PID.
# $1 = dialog title, $2 = dialog text, $3 = "stopped" to only list
# suspended (SIGSTOP'd) processes, otherwise the top 20 by CPU.
pick_pid() {
    local title="$1" text="$2" filter="${3:-}"
    local process_list

    if [[ "$filter" == "stopped" ]]; then
        process_list=$(ps -eo pid,comm,stat --no-headers | awk '$3 ~ /T/ {print $1, $2}')
    else
        process_list=$(ps -eo pid,comm --sort=-%cpu --no-headers | head -n 20)
    fi

    local zenity_args=()
    while read -r pid comm; do
        [[ -z "$pid" ]] && continue
        zenity_args+=("$pid" "$comm")
    done <<< "$process_list"

    if [[ ${#zenity_args[@]} -eq 0 ]]; then
        return 2  # distinct from zenity's own 0=selected/1=cancelled
    fi

    zenity --list --title="$title" --text="$text" "${ICON_ARGS[@]}" \
        --cancel-label="Back" \
        --column="PID" --column="Command" --print-column=1 \
        "${zenity_args[@]}"
}

# Opens a URL in the user's browser, or shows it if nothing can.
# wslview (from the wslu package) is checked because this tool is commonly run
# under WSL, where xdg-open usually isn't installed but a Windows browser is
# still reachable.
open_url() {
    local url="$1" opener
    for opener in xdg-open wslview; do
        if command -v "$opener" &>/dev/null; then
            "$opener" "$url" &>/dev/null &
            return 0
        fi
    done

    zenity --info "${NO_MARKUP[@]}" --text="No browser opener found (tried xdg-open, wslview).
Visit: $url"
}

# Shows a read-only report. Both buttons are labelled "Back" because both do
# the same thing here — dismiss the report and return to the menu. Zenity
# rejects --no-cancel for --text-info ("not supported for this dialog"), so
# collapsing this to one button isn't an option.
show_report() {
    local title="$1" file="$2"
    zenity --text-info --title="$title" "${ICON_ARGS[@]}" \
        --filename="$file" --width=800 --height=400 \
        --ok-label="Back" --cancel-label="Back"
}

while true; do
    ACTION=$(zenity --list --title="Process Manager GUI" "${ICON_ARGS[@]}" \
        --text="Select an action to perform:" \
        --radiolist \
        --cancel-label="Exit" \
        --column="Select" --column="Action" \
        TRUE "Show Process Info" \
        FALSE "Search a Process" \
        FALSE "Show Alerts (High CPU/MEM)" \
        FALSE "Live Dashboard" \
        FALSE "Export to CSV" \
        FALSE "Kill a Process" \
        FALSE "Suspend a Process" \
        FALSE "Resume a Process" \
        FALSE "Credits" \
        FALSE "Exit")

    case "$ACTION" in
        "Show Process Info")
            TEMP_FILE=$(mktemp)
            ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 20 > "$TEMP_FILE"

            if [[ -s "$TEMP_FILE" ]]; then
                show_report "Top 20 Processes" "$TEMP_FILE"
            else
                zenity --error "${NO_MARKUP[@]}" --text="Could not fetch process info."
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Search a Process")
            QUERY=$(zenity --entry --title="Search Process" "${ICON_ARGS[@]}" \
                --cancel-label="Back" --text="Enter process name or PID:")

            if [[ -z "$QUERY" ]]; then
                continue  # User clicked Back or entered nothing
            fi

            PS_OUTPUT=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu)
            TEMP_FILE=$(mktemp)
            {
                head -n 1 <<< "$PS_OUTPUT"
                tail -n +2 <<< "$PS_OUTPUT" | grep -iF -- "$QUERY"
            } > "$TEMP_FILE"

            if [[ $(wc -l < "$TEMP_FILE") -le 1 ]]; then
                zenity --error "${NO_MARKUP[@]}" --text="No matching processes found for '$QUERY'."
            else
                show_report "Search Results: $QUERY" "$TEMP_FILE"
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Show Alerts (High CPU/MEM)")
            PS_OUTPUT=$(ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu)
            TEMP_FILE=$(mktemp)
            {
                head -n 1 <<< "$PS_OUTPUT"
                tail -n +2 <<< "$PS_OUTPUT" | awk -v t="$HIGH_THRESHOLD" '$(NF)+0 >= t || $(NF-1)+0 >= t'
            } > "$TEMP_FILE"

            if [[ $(wc -l < "$TEMP_FILE") -le 1 ]]; then
                zenity --info "${NO_MARKUP[@]}" --text="No processes currently exceed ${HIGH_THRESHOLD}% CPU or MEM."
            else
                show_report "High CPU/MEM Alerts" "$TEMP_FILE"
            fi

            rm -f "$TEMP_FILE"
            ;;

        "Live Dashboard")
            if ! command -v python3 &>/dev/null; then
                zenity --error "${NO_MARKUP[@]}" --text="python3 is required for the live dashboard.
Install it with: sudo apt install python3"
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
                zenity --error "${NO_MARKUP[@]}" --text="No terminal emulator found to launch the dashboard.
Install one with: sudo apt install xterm -y
Or run manually: python3 \"$SCRIPT_DIR/modules/dashboard.py\""
                continue
            fi

            # Terminals disagree on how to take a command plus arguments:
            # gnome-terminal's -e is deprecated and parses only a single
            # string (so "-e python3 /path" leaves /path as a stray argument
            # and fails), while xterm and konsole take the rest as argv.
            # x-terminal-emulator is a Debian alternatives symlink — usually
            # gnome-terminal on Ubuntu — so resolve it before deciding.
            TERMINAL_KIND="$TERMINAL"
            if [[ "$TERMINAL" == "x-terminal-emulator" ]]; then
                TERMINAL_KIND=$(basename "$(readlink -f "$(command -v x-terminal-emulator)")")
            fi

            case "$TERMINAL_KIND" in
                gnome-terminal*)
                    "$TERMINAL" -- python3 "$SCRIPT_DIR/modules/dashboard.py" &
                    ;;
                xfce4-terminal*)
                    "$TERMINAL" -x python3 "$SCRIPT_DIR/modules/dashboard.py" &
                    ;;
                *)
                    "$TERMINAL" -e python3 "$SCRIPT_DIR/modules/dashboard.py" &
                    ;;
            esac
            ;;

        "Export to CSV")
            if OUTFILE=$(export_csv); then
                zenity --info "${NO_MARKUP[@]}" --text="Exported current process snapshot to:
$(pwd)/$OUTFILE"
            else
                zenity --error "${NO_MARKUP[@]}" --text="Could not write the CSV snapshot.
This directory isn't writable:
$(pwd)"
            fi
            ;;

        "Kill a Process")
            PID=$(pick_pid "Kill Process" "Select a process to kill")

            if [[ -z "$PID" ]]; then
                continue  # User clicked Back, or no processes to show
            fi

            kill "$PID" && \
            zenity --info "${NO_MARKUP[@]}" --text="Process $PID killed." || \
            zenity --error "${NO_MARKUP[@]}" --text="Failed to kill process $PID."
            ;;

        "Suspend a Process")
            PID=$(pick_pid "Suspend Process" "Select a process to suspend")

            if [[ -z "$PID" ]]; then
                continue
            fi

            kill -STOP "$PID" && \
            zenity --info "${NO_MARKUP[@]}" --text="Process $PID suspended." || \
            zenity --error "${NO_MARKUP[@]}" --text="Failed to suspend process $PID."
            ;;

        "Resume a Process")
            PID=$(pick_pid "Resume Process" "Select a suspended process to resume" "stopped")
            PICK_STATUS=$?

            if [[ "$PICK_STATUS" -eq 2 ]]; then
                zenity --info "${NO_MARKUP[@]}" --text="No suspended processes found."
                continue
            elif [[ -z "$PID" ]]; then
                continue  # user clicked Back
            fi

            kill -CONT "$PID" && \
            zenity --info "${NO_MARKUP[@]}" --text="Process $PID resumed." || \
            zenity --error "${NO_MARKUP[@]}" --text="Failed to resume process $PID."
            ;;

        "Credits")
            # The only dialog that opts into markup: every value here is a
            # literal this script owns, with '&' pre-escaped as '&amp;'.
            # A real newline works under markup; '\n' would too, but staying
            # consistent with the --no-markup dialogs avoids a trap later.
            #
            # Zenity's button contract: OK exits 0; an --extra-button exits 1
            # and prints its own label; Cancel exits 1 printing nothing. That
            # is what separates the two profile buttons from Back.
            CREDIT_CHOICE=$(zenity --question --title="Credits" "${ICON_ARGS[@]}" --width=460 \
                --text="<b>Process Monitor &amp; Manager</b>

<b>Sufiyan Aasim</b>  (@SufiyanAasim)
Author &amp; Maintainer
sufiyanaasim@outlook.com

<b>Muhammad Taha Siddiqui</b>  (@13eeCoder)
Contributor — process control
tahasiddiqui2100@gmail.com" \
                --ok-label="GitHub: @SufiyanAasim" \
                --extra-button="GitHub: @13eeCoder" \
                --cancel-label="Back")
            CREDIT_STATUS=$?

            if [[ "$CREDIT_STATUS" -eq 0 ]]; then
                open_url "https://github.com/SufiyanAasim"
            elif [[ "$CREDIT_CHOICE" == "GitHub: @13eeCoder" ]]; then
                open_url "https://github.com/13eeCoder"
            fi
            ;;

        "Exit")
            break
            ;;

        *)
            # Cancel, Exit button, or the window's close (X) button.
            break
            ;;
    esac
done
