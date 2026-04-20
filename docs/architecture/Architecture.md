# Architecture

## Overview

Process Monitor & Manager follows a thin-orchestrator design: `monitor.sh` and `monitor_gui.sh` are entry points that delegate to shared modules, which in turn wrap standard Linux process tools (`ps`, `pstree`, `kill`). The CLI and GUI cover the same feature set independently — there is no shared runtime state between them.

```
┌──────────────────────────────────────────────┐
│                  Entry Points                │
│         monitor.sh          monitor_gui.sh   │
└──────────┬─────────────────────┬─────────────┘
           │                     │
   ┌───────▼───────┐     ┌───────▼────────┐
   │   CLI Menu     │     │  Zenity Dialogs │
   │ (input_module) │     │  (inline case)  │
   └───────┬───────┘     └───────┬────────┘
           │                     │
   ┌───────▼─────────────────────▼────────┐
   │              modules/                │
   │  monitor_module.sh — info/search/     │
   │    alerts/tree/colorizing             │
   │  manage_module.sh  — kill/suspend/    │
   │    resume                             │
   └───────────────────┬───────────────────┘
                       │
            ┌──────────▼──────────┐
            │  ps · pstree · kill  │
            └─────────────────────┘

  modules/dashboard.py — standalone, launched by either entry point.
  Owns its own process fetch/render/input loop (ProcessManager + Dashboard).
```

---

## Module Responsibilities

| Module | Responsibility |
|--------|-----------------|
| `monitor.sh` | CLI entry point. Renders the menu, reads a choice, dispatches via `input_module.sh`. |
| `monitor_gui.sh` | GUI entry point. Zenity radiolist loop; each action is handled inline. |
| `modules/monitor_module.sh` | `show_process_info`, `show_process_tree`, `search_process`, `show_alerts`, `colorize_line`, `launch_dashboard`. |
| `modules/manage_module.sh` | `kill_process`, `suspend_process`, `resume_process` — all operate on a user-supplied PID. |
| `modules/input_module.sh` | `handle_user_input` — maps a CLI menu choice to the corresponding function. |
| `modules/dashboard.py` | `Process` (data holder), `ProcessManager` (fetch/filter/signal via `ps`/`kill`), `Dashboard` (curses render + input loop: search, kill, suspend, resume, quit). |

---

## Data Flow — Process Info

1. `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu` produces the sorted process table.
2. `colorize_line` inspects the last whitespace-separated field (`%CPU`) of each line and wraps it in an ANSI color code based on the configured thresholds.
3. The GUI variant pipes the same `ps` output straight into a `zenity --text-info` dialog — no coloring, since Zenity's text widget does not render ANSI escapes.

## Data Flow — Live Dashboard

1. `ProcessManager.fetch()` shells out to the same `ps` command and parses each line into a `Process` object. PID/PPID are taken as the first two tokens and `%MEM`/`%CPU` as the last two, so multi-word commands (with embedded flags/arguments) don't misalign the columns.
2. `Dashboard.run()` loops on a timer (`stdscr.timeout`), re-fetching and re-rendering on every refresh tick or keypress.
3. Signals (`k`/`s`/`r`) call `ProcessManager.send_signal()`, which shells out to `kill -<SIGNAL> <pid>` via `subprocess.run` with an argument list (no shell interpolation).
