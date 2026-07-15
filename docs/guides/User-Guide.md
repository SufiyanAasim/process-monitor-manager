# User Guide

## CLI mode

```bash
./monitor.sh
```

```
============================
 Process Monitor & Manager
============================
1. Show Process Info
2. Kill Process
3. Suspend Process
4. Resume Process
5. Show Process Tree
6. Search Process
7. Show Alerts (High CPU/MEM)
8. Live Dashboard
9. Export to CSV
10. Credits
11. Exit
============================
```

- **1 — Show Process Info.** Top processes sorted by CPU, color-coded: red ≥50%, yellow ≥20%, green below.
- **2/3/4 — Kill / Suspend / Resume.** Prompts for a PID, then sends `SIGTERM` / `SIGSTOP` / `SIGCONT`.
- **5 — Show Process Tree.** Full hierarchy via `pstree -p`.
- **6 — Search Process.** Prompts for a name or PID, filters the process table.
- **7 — Show Alerts.** Lists every process currently at or above the CPU/MEM threshold.
- **8 — Live Dashboard.** Launches `modules/dashboard.py` — see below.
- **9 — Export to CSV.** Writes the current process table to `process_snapshot_<timestamp>.csv` in the working directory.
- **10 — Credits.** Contributors, the GitHub repository link, and a contact email.
- **11 — Exit.**

## GUI mode

```bash
./monitor.sh --gui
```

A Zenity radiolist mirrors every CLI action above, including "Export to CSV" and "Credits" — with a few differences from the CLI:

- **Kill / Suspend / Resume pick a process from a list** instead of asking you to type a PID. "Resume" only lists processes that are currently suspended.
- **No color coding.** Zenity's text widget can't render ANSI colors, so GUI output is plain text — `PMM_HIGH_THRESHOLD` still controls what counts as an alert, but `PMM_MED_THRESHOLD` has no effect in GUI mode.
- **Every dialog shows the project icon** (`assets/icon.svg`) as its window icon.

### Getting around

Every action opens a dialog and returns you to the main menu when you're done:

- **Back** — in any sub-dialog (process pickers, the search prompt, Credits, and report views), returns to the main menu without doing anything.
- **Exit** — pick "Exit" from the menu, click the menu's **Exit** button, or just close the window with **X**.
- **"Credits" has a clickable "Open GitHub" button** that launches the repository in your default browser via `xdg-open`, in addition to the contributor/contact text shown in the CLI version.

"Live Dashboard" opens the dashboard in a detected terminal emulator (`xterm`, `gnome-terminal`, `konsole`, or `xfce4-terminal` — install one if none is found).

## Live Dashboard

```bash
python3 modules/dashboard.py
```

An auto-refreshing (every 2 seconds) full-screen view, color-coded the same way as the CLI:

| Key | Action |
|-----|--------|
| `/` | Search / filter by name or PID |
| `o` | Cycle sort order — CPU → MEM → PID |
| `e` | Export the current (filtered/sorted) view to CSV |
| `k` | Kill a process by PID |
| `s` | Suspend a process by PID |
| `r` | Resume a process by PID |
| `q` | Quit |

## Configuring alert/color thresholds

`PMM_HIGH_THRESHOLD` (default `50`) controls what counts as an alert everywhere (CLI, GUI, dashboard) and shows red in the CLI and dashboard. `PMM_MED_THRESHOLD` (default `20`) controls the yellow cutoff in the CLI and dashboard only — the GUI never color-codes, so it has no effect there.

**One-off**, via environment variable (highest precedence):
```bash
PMM_HIGH_THRESHOLD=80 PMM_MED_THRESHOLD=40 ./monitor.sh
PMM_HIGH_THRESHOLD=80 python3 modules/dashboard.py
```

**Persistent**, via config file (used when no environment variable is set):
```bash
mkdir -p ~/.config/process-monitor-manager
cp config/process-monitor-manager.example ~/.config/process-monitor-manager/config
```
Edit the copied file's `PMM_HIGH_THRESHOLD=`/`PMM_MED_THRESHOLD=` lines. Both the Bash modules and `dashboard.py` read it.

## Example: finding and stopping a runaway process

```bash
./monitor.sh
# 7  → Show Alerts, note the PID of the offending process
# 2  → Kill Process, enter that PID
```

Or from the Live Dashboard: press `/`, type part of the process name, then `k` and the PID shown.

## Example: exporting a filtered snapshot

```bash
./monitor.sh
# 6  → Search Process, enter "python" — narrows the table
```

Or from the Live Dashboard: press `/` and search first, then `e` — the export contains only what's currently on screen, not the full process list.
