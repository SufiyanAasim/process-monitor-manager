#!/bin/bash
# ==============================================================================
# Process Control Module (modules/manage_module.sh)
# @author: Muhammad Taha Siddiqui (@13eeCoder) <tahasiddiqui2100@gmail.com>
# Responsibilities: Process termination (SIGTERM/SIGKILL), suspension (SIGSTOP),
# resumption (SIGCONT), and strict PID/self-session validation (_validate_pid).
# ==============================================================================

# Validates that $1 looks like a real PID and isn't this shell's own process,
# printing a friendly message and returning non-zero if not.
_validate_pid() {
    local pid="$1"

    if [[ -z "$pid" ]] || [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        echo "Invalid PID: '$pid' (must be a positive number)."
        return 1
    fi

    if [[ "$pid" == "$$" ]] || [[ "$pid" == "$PPID" ]]; then
        echo "Refusing to signal PID $pid — that's this session's own shell."
        return 1
    fi

    return 0
}

kill_process() {
    read -rp "Enter PID to kill: " pid
    _validate_pid "$pid" || return
    kill "$pid" && echo "Process $pid terminated." || echo "Failed to kill process $pid."
}

suspend_process() {
    read -rp "Enter PID to suspend: " pid
    _validate_pid "$pid" || return
    kill -STOP "$pid" && echo "Process $pid suspended." || echo "Failed to suspend process $pid."
}

resume_process() {
    read -rp "Enter PID to resume: " pid
    _validate_pid "$pid" || return
    kill -CONT "$pid" && echo "Process $pid resumed." || echo "Failed to resume process $pid."
}
