#!/bin/bash
# Basic functional sanity checks — not a full unit-test suite, just enough
# to catch the kind of regressions this project has actually hit before
# (broken module paths, signal handling, dashboard parsing).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0

check() {
    local description="$1"
    local result="$2"
    if [[ "$result" -eq 0 ]]; then
        echo "PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $description"
        FAIL=$((FAIL + 1))
    fi
}

# --- modules source cleanly ---
bash -n monitor.sh monitor_gui.sh modules/*.sh
check "all scripts pass bash -n" $?

# --- module functions load and are callable ---
(
    source modules/monitor_module.sh
    source modules/manage_module.sh
    source modules/input_module.sh
    declare -F show_process_info >/dev/null && \
    declare -F search_process >/dev/null && \
    declare -F show_alerts >/dev/null && \
    declare -F kill_process >/dev/null && \
    declare -F suspend_process >/dev/null && \
    declare -F resume_process >/dev/null && \
    declare -F handle_user_input >/dev/null
)
check "expected functions are defined after sourcing modules" $?

# --- colorize_line thresholds ---
(
    source modules/monitor_module.sh
    RED_OUT=$(colorize_line "  1 1 heavy 1.0 75")
    YEL_OUT=$(colorize_line "  1 1 medium 1.0 30")
    GRN_OUT=$(colorize_line "  1 1 light 1.0 5")
    [[ "$RED_OUT" == *$'\033[1;31m'* ]] && \
    [[ "$YEL_OUT" == *$'\033[1;33m'* ]] && \
    [[ "$GRN_OUT" == *$'\033[0;32m'* ]]
)
check "colorize_line applies red/yellow/green by CPU threshold" $?

# --- suspend/resume/kill against a self-spawned dummy process ---
sleep 300 &
DUMMY_PID=$!
sleep 0.5
kill -STOP "$DUMMY_PID" 2>/dev/null
STOPPED=$(ps -o stat= -p "$DUMMY_PID" 2>/dev/null | grep -c 'T')
check "SIGSTOP suspends the dummy process" $((STOPPED == 0))
kill -CONT "$DUMMY_PID" 2>/dev/null
check "SIGCONT resumes the dummy process" $?
kill "$DUMMY_PID" 2>/dev/null
sleep 0.5
kill -0 "$DUMMY_PID" 2>/dev/null
check "SIGTERM terminates the dummy process" $((! $?))

# --- dashboard.py compiles and its parsing logic is correct ---
python3 -m py_compile modules/dashboard.py
check "modules/dashboard.py compiles" $?

python3 - <<'PYEOF'
import sys, types
sys.modules['curses'] = types.ModuleType('curses')
sys.path.insert(0, 'modules')
from dashboard import ProcessManager

pm = ProcessManager()

class FakeResult:
    stdout = (
        '  PID  PPID CMD                         %MEM %CPU\n'
        '   100     1 /usr/bin/python3 -m http.server 8000   2.0 75.0\n'
    )

import subprocess
subprocess.run = lambda *a, **k: FakeResult()
procs = pm.fetch()
assert len(procs) == 1
assert procs[0].cmd == '/usr/bin/python3 -m http.server 8000'
assert procs[0].cpu == '75.0'
sys.exit(0)
PYEOF
check "ProcessManager.fetch() parses multi-word commands correctly" $?

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
