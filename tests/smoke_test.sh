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
# STOPPED is 1 when the process is correctly stopped, so "STOPPED == 0" (i.e.
# "not stopped") is the failure condition check() should report as non-zero.
check "SIGSTOP suspends the dummy process" $((STOPPED == 0))
kill -CONT "$DUMMY_PID" 2>/dev/null
check "SIGCONT resumes the dummy process" $?
kill "$DUMMY_PID" 2>/dev/null
sleep 0.5
kill -0 "$DUMMY_PID" 2>/dev/null
# kill -0 exits 0 while the process still exists, so negate it: we want this
# check to report success once the process is actually gone.
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

# --- export_csv writes a well-formed CSV and prints only its filename ---
(
    cd "$(mktemp -d)" || exit 1
    source "$SCRIPT_DIR/modules/monitor_module.sh"
    CSV=$(export_csv)
    [[ "$CSV" == process_snapshot_*.csv ]] && \
    [[ -f "$CSV" ]] && \
    [[ $(head -1 "$CSV") == "PID,PPID,CMD,%MEM,%CPU" ]] && \
    [[ $(wc -l < "$CSV") -gt 1 ]]
)
check "export_csv writes a header + at least one data row, prints only the filename" $?

# --- export_csv must fail loudly, not report success for a file it never wrote.
# The .deb wrapper used to cd into a root-owned install dir, so this was the
# normal case for every packaged install, not an edge case.
(
    RO_DIR="$(mktemp -d)" || exit 1
    chmod 500 "$RO_DIR"
    cd "$RO_DIR" || exit 1
    source "$SCRIPT_DIR/modules/monitor_module.sh"

    OUT=$(export_csv 2>/dev/null)
    RC=$?
    cd /tmp || exit 1
    chmod 700 "$RO_DIR"; rm -rf "$RO_DIR"

    # Must report failure AND print no filename.
    [[ "$RC" -ne 0 ]] && [[ -z "$OUT" ]]
)
check "export_csv returns non-zero and prints nothing when the directory is unwritable" $?

# --- the .deb wrapper must not cd into the (root-owned) install directory ---
(
    ! grep -qE '^cd "/usr/lib/' "$SCRIPT_DIR/scripts/build-deb.sh"
)
check "build-deb.sh wrapper runs from the user's working directory, not the install dir" $?

# --- an unwritable directory must not crash the curses dashboard ---
python3 - <<PYEOF
import sys, types, os, tempfile, stat
sys.modules['curses'] = types.ModuleType('curses')
sys.path.insert(0, 'modules')
from dashboard import Process, ProcessManager

ro = tempfile.mkdtemp()
os.chmod(ro, stat.S_IRUSR | stat.S_IXUSR)
cwd = os.getcwd()
os.chdir(ro)
try:
    result = ProcessManager().export_csv([Process('1', '0', 'init', '0.0', '0.0')])
finally:
    os.chdir(cwd)
    os.chmod(ro, stat.S_IRWXU)
    os.rmdir(ro)

# None signals failure to the caller; an exception would kill the whole TUI.
assert result is None, f"expected None on an unwritable dir, got {result!r}"
sys.exit(0)
PYEOF
check "dashboard export_csv returns None instead of raising on an unwritable dir" $?

# --- resizing the terminal must not kill the dashboard.
# curses.LINES/COLS are captured at initscr and go stale on resize, so drawing
# rows based on them lands past the new last row and raises curses.error.
# Needs a real pty, so this drives draw() through an actual curses session.
python3 - <<PYEOF
import os, pty, sys

CHILD = '''
import curses, fcntl, struct, sys, termios
sys.path.insert(0, "$SCRIPT_DIR/modules")
from dashboard import Dashboard, Process, ProcessManager

def resize(rows, cols):
    fcntl.ioctl(sys.stdout.fileno(), termios.TIOCSWINSZ,
                struct.pack("HHHH", rows, cols, 0, 0))

def main(stdscr):
    curses.start_color(); curses.use_default_colors()
    for i, c in enumerate((curses.COLOR_RED, curses.COLOR_YELLOW, curses.COLOR_GREEN), 1):
        curses.init_pair(i, c, -1)
    dash = Dashboard(ProcessManager())
    procs = [Process(str(i), "1", "proc-%d" % i, "1.0", "5.0") for i in range(40)]
    dash.draw(stdscr, procs)
    resize(10, 40)          # shrink mid-session
    dash.draw(stdscr, procs)
    resize(3, 20)           # pathologically small
    dash.query = "z" * 500  # and an over-long filter line
    dash.draw(stdscr, procs)
    return "SURVIVED"

print(curses.wrapper(main))
'''

with open("/tmp/_pmm_resize_child.py", "w") as f:
    f.write(CHILD)

pid, fd = pty.fork()
if pid == 0:
    os.execvp("python3", ["python3", "/tmp/_pmm_resize_child.py"])

out = b""
try:
    while True:
        chunk = os.read(fd, 4096)
        if not chunk:
            break
        out += chunk
except OSError:
    pass
_, status = os.waitpid(pid, 0)
os.unlink("/tmp/_pmm_resize_child.py")

# A curses.error traceback would leave "SURVIVED" unprinted.
sys.exit(0 if (b"SURVIVED" in out and os.WEXITSTATUS(status) == 0) else 1)
PYEOF
check "dashboard survives terminal resize (uses getmaxyx, not stale curses.LINES)" $?

# --- PID validation rejects bad input and self-signaling ---
(
    source modules/manage_module.sh
    ! _validate_pid "" >/dev/null 2>&1 && \
    ! _validate_pid "abc" >/dev/null 2>&1 && \
    ! _validate_pid "12.5" >/dev/null 2>&1 && \
    ! _validate_pid "$$" >/dev/null 2>&1 && \
    _validate_pid "1" >/dev/null 2>&1
)
check "_validate_pid rejects empty/non-numeric/self PIDs and accepts a real one" $?

# --- search_process treats the query as a literal string, not a regex ---
(
    source modules/monitor_module.sh
    # "a.b" as a regex would also match "aXb"; as a literal it must not.
    printf '  1 1 aXb 0.0 0.0\n' | grep -iF -- "a.b" >/dev/null
)
check "search uses fixed-string (-F) matching, not regex" $((! $?))

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

python3 - <<'PYEOF'
import sys, types, os
sys.modules['curses'] = types.ModuleType('curses')
sys.path.insert(0, 'modules')
from dashboard import Process, ProcessManager, Dashboard

pm = ProcessManager()
procs = [Process('120', '1', 'target', '0.0', '0.0'), Process('999', '1', 'other', '0.0', '0.0')]

# Partial PID match must behave like the CLI's substring grep search, not
# require an exact match.
assert [p.pid for p in pm.filter(procs, '12')] == ['120']
assert [p.pid for p in pm.filter(procs, '9')] == ['999']

dash = Dashboard(pm)
valid, _ = dash._validate_pid(str(os.getpid()))
assert valid is False, "dashboard must refuse to signal its own PID"
valid, _ = dash._validate_pid("not-a-pid")
assert valid is False
valid, _ = dash._validate_pid("1")
assert valid is True
sys.exit(0)
PYEOF
check "dashboard filter() supports partial PID match and _validate_pid guards self-signaling" $?

# --- credits list both members, each with their own profile link and email ---
(
    source modules/monitor_module.sh
    OUT=$(show_credits)
    [[ "$OUT" == *"github.com/SufiyanAasim"* ]] && \
    [[ "$OUT" == *"github.com/13eeCoder"* ]] && \
    [[ "$OUT" == *"sufiyanaasim@outlook.com"* ]] && \
    [[ "$OUT" == *"tahasiddiqui2100@gmail.com"* ]] && \
    [[ "$OUT" == *"Author"* ]] && \
    [[ "$OUT" == *"Contributor"* ]]
)
check "CLI credits list both members with separate GitHub links and emails" $?

# --- the GUI credits dialog offers a separate button per member ---
(
    grep -q -- '--ok-label="GitHub: @SufiyanAasim"' "$SCRIPT_DIR/monitor_gui.sh" && \
    grep -q -- '--extra-button="GitHub: @13eeCoder"' "$SCRIPT_DIR/monitor_gui.sh" && \
    grep -q 'github.com/SufiyanAasim"' "$SCRIPT_DIR/monitor_gui.sh" && \
    grep -q 'github.com/13eeCoder"' "$SCRIPT_DIR/monitor_gui.sh"
)
check "GUI credits give each member their own clickable GitHub button" $?

# --- roles must not be asserted backwards.
# Scoped to surfaces that *assert* attribution (credits output, README/LICENSE,
# release-doc contributor table rows) rather than any prose mentioning it —
# CHANGELOG and the v5.0.0 notes legitimately describe the old, wrong roles in
# order to record that they were corrected.
(
    # Nobody carries the "Original Author" title any more — Sufiyan is "Author".
    # A name and its GitHub handle sit on separate lines in the credits output,
    # so pairing them with a single line-based grep silently matches nothing;
    # check for the stale title itself instead.
    OFFENDERS=$(
        {
            grep -Hn "Original Author" "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/LICENSE" \
                "$SCRIPT_DIR/modules/monitor_module.sh" "$SCRIPT_DIR/monitor_gui.sh" 2>/dev/null
            grep -Hn "^|.*Original Author" "$SCRIPT_DIR"/docs/releases/*.md 2>/dev/null
        }
    )
    [[ -z "$OFFENDERS" ]] || { echo "  stale 'Original Author' attribution:"; echo "$OFFENDERS"; exit 1; }
)
check "no attribution surface still says 'Original Author'" $?

# --- the rendered credits pair each name with the right role ---
(
    source modules/monitor_module.sh
    OUT=$(show_credits)
    TAHA_LINE=$(grep -i "Muhammad Taha" <<< "$OUT")
    SUFI_LINE=$(grep -i "Sufiyan Aasim" <<< "$OUT")
    [[ "$TAHA_LINE" == *Contributor* ]] && \
    [[ "$TAHA_LINE" != *Author* ]] && \
    [[ "$SUFI_LINE" == *Author* ]]
)
check "CLI credits pair Sufiyan with Author and Taha with Contributor" $?

# --- pre-release status must agree across every place that states it:
# the release note, the releases index, CHANGELOG, and (via the marker the
# workflow greps for) the GitHub release itself.
(
    for notes in "$SCRIPT_DIR"/docs/releases/v*.md; do
        tag="v$(basename "$notes" .md | sed 's/^v//')"

        # This is the exact pattern .github/workflows/release.yml greps for.
        if grep -qi '^> \*\*Pre-release\.\*\*' "$notes"; then
            doc_pre=yes
        else
            doc_pre=no
        fi

        if grep -q "\[$tag (.*)\](${tag}\.md) — Pre-release" "$SCRIPT_DIR/docs/releases/README.md"; then
            index_pre=yes
        else
            index_pre=no
        fi

        if [[ "$doc_pre" != "$index_pre" ]]; then
            echo "  $tag: release note says pre-release=$doc_pre but the index says $index_pre"
            exit 1
        fi
    done
)
check "pre-release status agrees between each release note and the releases index" $?

# --- the workflow must actually pass prerelease through, or the doc marker is
# decorative and every version publishes as a full release.
(
    grep -q 'prerelease: \${{ steps.prerelease.outputs.value }}' "$SCRIPT_DIR/.github/workflows/release.yml" && \
    grep -q "Pre-release" "$SCRIPT_DIR/.github/workflows/release.yml"
)
check "release.yml derives prerelease from the release note and passes it through" $?

# --- CODEOWNERS reflects the agreed split ---
(
    grep -qE '^\*[[:space:]]+@SufiyanAasim' "$SCRIPT_DIR/.github/CODEOWNERS" && \
    grep -qE 'manage_module\.sh[[:space:]]+@13eeCoder' "$SCRIPT_DIR/.github/CODEOWNERS"
)
check "CODEOWNERS routes manage_module.sh to @13eeCoder, the rest to @SufiyanAasim" $?

# --- both SVG assets exist; icon.svg is the one the GUI passes to zenity ---
(
    [[ -f "$SCRIPT_DIR/assets/logo.svg" ]] && \
    [[ -f "$SCRIPT_DIR/assets/icon.svg" ]] && \
    python3 -c "import xml.etree.ElementTree as ET; ET.parse('$SCRIPT_DIR/assets/icon.svg'); ET.parse('$SCRIPT_DIR/assets/logo.svg')" 2>/dev/null && \
    grep -q 'assets/icon.svg' "$SCRIPT_DIR/monitor_gui.sh"
)
check "assets/logo.svg + icon.svg are valid SVG and the GUI prefers icon.svg" $?

# --- icon.svg has no fixed width/height, so it scales to any icon size ---
(
    ! grep -qE '<svg[^>]*[[:space:]](width|height)=' "$SCRIPT_DIR/assets/icon.svg"
)
check "icon.svg is viewBox-only (scales cleanly to any rendered size)" $?

# --- every zenity dialog that interpolates a value must disable Pango markup.
# A path or search query containing '&' (e.g. ".../Fully Tested & Deployed/...")
# otherwise aborts the dialog with a markup parse error. Credits is the one
# intentional exception: static text this script owns, with '&' pre-escaped.
(
    # Join backslash line-continuations, then extract each zenity invocation
    # individually (up to the next && / || / pipe) — checking per-line instead
    # would let one safe call in an a && b || c chain mask an unsafe sibling.
    OFFENDERS=$(sed -e ':a' -e '/\\$/{N;s/\\\n//;ta' -e '}' "$SCRIPT_DIR/monitor_gui.sh" \
        | grep -oE 'zenity --(info|error|question)[^|&]*' \
        | grep -v 'NO_MARKUP' \
        | grep -v -- '--title="Credits"')
    [[ -z "$OFFENDERS" ]] || { echo "  markup-unsafe dialog(s):"; echo "$OFFENDERS"; exit 1; }
)
check "every zenity dialog passes --no-markup (except the static Credits text)" $?

# --- --no-markup also disables '\n' escape handling, so a literal backslash-n
# in one of those dialogs renders on screen verbatim instead of breaking the
# line. Markup dialogs (Credits) still interpret '\n', so they're exempt.
(
    OFFENDERS=$(sed -e ':a' -e '/\\$/{N;s/\\\n//;ta' -e '}' "$SCRIPT_DIR/monitor_gui.sh" \
        | grep -oE 'zenity --(info|error|question)[^|&]*' \
        | grep 'NO_MARKUP' \
        | grep '\\n')
    [[ -z "$OFFENDERS" ]] || { echo "  literal \\n in a --no-markup dialog:"; echo "$OFFENDERS"; exit 1; }
)
check "no --no-markup dialog uses a literal \\n (it would render verbatim)" $?

# --- sub-dialogs offer a way back to the main menu ---
(
    # The process pickers, the search prompt, and the report views must each
    # offer Back; the main menu's cancel is Exit, not Back.
    [[ $(grep -c -- '--cancel-label="Back"' "$SCRIPT_DIR/monitor_gui.sh") -ge 3 ]] && \
    grep -q -- '--ok-label="Back"' "$SCRIPT_DIR/monitor_gui.sh" && \
    grep -q -- '--cancel-label="Exit"' "$SCRIPT_DIR/monitor_gui.sh"
)
check "GUI sub-dialogs expose Back, main menu exposes Exit" $?

# --- zenity actually honours the button-relabel flags on the dialog types we
# use them with. Zenity prints "<flag> is not supported for this dialog" and
# ignores the flag rather than failing, so a silently-dropped Back button would
# otherwise look identical to a working one. Skipped without a display.
if command -v zenity &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    (
        REPORT_FILE=$(mktemp)
        echo "sample" > "$REPORT_FILE"
        UNSUPPORTED=$(
            {
                timeout 2 zenity --text-info --filename="$REPORT_FILE" --ok-label="Back" --cancel-label="Back"
                timeout 2 zenity --list --column=PID --column=Command 1 sh --cancel-label="Back"
                timeout 2 zenity --entry --text="q" --cancel-label="Back"
            } 2>&1 | grep -i "not supported for this dialog"
        )
        rm -f "$REPORT_FILE"
        [[ -z "$UNSUPPORTED" ]] || { echo "  zenity ignored: $UNSUPPORTED"; exit 1; }
    )
    check "zenity accepts --ok-label/--cancel-label on the dialogs the GUI uses" $?
else
    echo "SKIP: zenity button-flag check (no display)"
fi

# --- config file precedence: default < config file < env var ---
(
    FAKE_HOME="$(mktemp -d)" || exit 1
    mkdir -p "$FAKE_HOME/.config/process-monitor-manager"
    echo "PMM_HIGH_THRESHOLD=77" > "$FAKE_HOME/.config/process-monitor-manager/config"
    echo "PMM_MED_THRESHOLD=33" >> "$FAKE_HOME/.config/process-monitor-manager/config"

    # config file alone (no env var set)
    RESULT1=$(HOME="$FAKE_HOME" bash -c 'unset XDG_CONFIG_HOME; source modules/monitor_module.sh; echo "$HIGH_THRESHOLD:$MED_THRESHOLD"')
    [[ "$RESULT1" == "77:33" ]] || exit 1

    # explicit env var still wins over the config file
    RESULT2=$(HOME="$FAKE_HOME" PMM_HIGH_THRESHOLD=99 bash -c 'unset XDG_CONFIG_HOME; source modules/monitor_module.sh; echo "$HIGH_THRESHOLD:$MED_THRESHOLD"')
    [[ "$RESULT2" == "99:33" ]]
)
check "config file is read when present, env var still overrides it (bash)" $?

python3 - <<PYEOF
import sys, types, os, tempfile
sys.modules['curses'] = types.ModuleType('curses')
sys.path.insert(0, 'modules')

fake_home = tempfile.mkdtemp()
config_dir = os.path.join(fake_home, '.config', 'process-monitor-manager')
os.makedirs(config_dir)
with open(os.path.join(config_dir, 'config'), 'w') as f:
    f.write('PMM_HIGH_THRESHOLD=77\nPMM_MED_THRESHOLD=33\n')

os.environ.pop('XDG_CONFIG_HOME', None)
os.environ['HOME'] = fake_home
os.environ.pop('PMM_HIGH_THRESHOLD', None)

import dashboard
assert dashboard._load_threshold('PMM_HIGH_THRESHOLD', 50) == 77.0
assert dashboard._load_threshold('PMM_MED_THRESHOLD', 20) == 33.0

os.environ['PMM_HIGH_THRESHOLD'] = '99'
assert dashboard._load_threshold('PMM_HIGH_THRESHOLD', 50) == 99.0
sys.exit(0)
PYEOF
check "config file is read when present, env var still overrides it (python)" $?

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
