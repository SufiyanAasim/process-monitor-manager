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
9. Exit
============================
```

- **1 — Show Process Info.** Top processes sorted by CPU, color-coded: red ≥50%, yellow ≥20%, green below.
- **2/3/4 — Kill / Suspend / Resume.** Prompts for a PID, then sends `SIGTERM` / `SIGSTOP` / `SIGCONT`.
- **5 — Show Process Tree.** Full hierarchy via `pstree -p`.
- **6 — Search Process.** Prompts for a name or PID, filters the process table.
- **7 — Show Alerts.** Lists every process currently at or above the 50% CPU/MEM threshold.
- **8 — Live Dashboard.** Launches `modules/dashboard.py` — see below.

## GUI mode

```bash
./monitor.sh --gui
```

A Zenity radiolist mirrors every CLI action above. "Live Dashboard" opens the dashboard in a detected terminal emulator (`xterm`, `gnome-terminal`, `konsole`, or `xfce4-terminal` — install one if none is found).

## Live Dashboard

```bash
python3 modules/dashboard.py
```

An auto-refreshing (every 2 seconds) full-screen view, color-coded the same way as the CLI:

| Key | Action |
|-----|--------|
| `/` | Search / filter by name or PID |
| `k` | Kill a process by PID |
| `s` | Suspend a process by PID |
| `r` | Resume a process by PID |
| `q` | Quit |

## Example: finding and stopping a runaway process

```bash
./monitor.sh
# 7  → Show Alerts, note the PID of the offending process
# 2  → Kill Process, enter that PID
```

Or from the Live Dashboard: press `/`, type part of the process name, then `k` and the PID shown.
