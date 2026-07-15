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

# --- configurable thresholds via env vars ---
(
    source modules/monitor_module.sh
    [[ "$HIGH_THRESHOLD" -eq 50 ]] && [[ "$MED_THRESHOLD" -eq 20 ]]
)
check "thresholds default to 50/20 when no env vars set" $?

(
    PMM_HIGH_THRESHOLD=80 PMM_MED_THRESHOLD=40 bash -c '
        source modules/monitor_module.sh
        [[ "$HIGH_THRESHOLD" -eq 80 ]] && [[ "$MED_THRESHOLD" -eq 40 ]]
    '
)
check "PMM_HIGH_THRESHOLD/PMM_MED_THRESHOLD override the defaults" $?

# --- export_csv writes a well-formed CSV of the current process list ---
(
    cd "$(mktemp -d)" || exit 1
    source "$SCRIPT_DIR/modules/monitor_module.sh"
    export_csv >/dev/null
    CSV=$(ls process_snapshot_*.csv 2>/dev/null | head -1)
    [[ -n "$CSV" ]] && [[ $(head -1 "$CSV") == "PID,PPID,CMD,%MEM,%CPU" ]] && [[ $(wc -l < "$CSV") -gt 1 ]]
)
check "export_csv writes a header + at least one data row" $?

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

python3 - <<'PYEOF'
import sys, types, os, tempfile
sys.modules['curses'] = types.ModuleType('curses')
sys.path.insert(0, 'modules')
from dashboard import Process, ProcessManager

pm = ProcessManager()
procs = [
    Process('100', '1', 'heavy', '2.0', '75.0'),
    Process('50', '1', 'light', '9.0', '5.0'),
    Process('300', '1', 'medium', '1.0', '30.0'),
]
assert [p.pid for p in pm.sort(procs, 'cpu')] == ['100', '300', '50']
assert [p.pid for p in pm.sort(procs, 'mem')] == ['50', '100', '300']
assert [p.pid for p in pm.sort(procs, 'pid')] == ['50', '100', '300']

cwd = os.getcwd()
os.chdir(tempfile.mkdtemp())
filename = pm.export_csv(procs)
with open(filename) as f:
    content = f.read()
os.chdir(cwd)
assert content.splitlines()[0] == 'PID,PPID,CMD,%MEM,%CPU'
assert len(content.splitlines()) == 4
sys.exit(0)
PYEOF
check "ProcessManager.sort() and export_csv() behave correctly" $?

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
