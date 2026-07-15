# Architecture

## Overview

Process Monitor & Manager follows a thin-orchestrator design: `monitor.sh` and `monitor_gui.sh` are entry points that delegate to shared modules, which in turn wrap standard Linux process tools (`ps`, `pstree`, `kill`). The CLI and GUI implement most of their own display logic independently (a terminal menu vs. Zenity dialogs), but `monitor_gui.sh` sources `modules/monitor_module.sh` directly to reuse `export_csv()`, `show_credits`, and the `HIGH_THRESHOLD`/`MED_THRESHOLD` constants, rather than duplicating that logic.

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
           │                     │ sources monitor_module.sh
           │                     │ (export_csv, thresholds only —
           │                     │  Kill/Search/Alerts stay GUI-native)
   ┌───────▼─────────────────────▼────────┐
   │              modules/                │
   │  monitor_module.sh — info/search/     │
   │    alerts/tree/colorizing/export      │
   │  manage_module.sh  — kill/suspend/    │
   │    resume, PID validation             │
   └───────────────────┬───────────────────┘
                       │
            ┌──────────▼──────────┐
            │  ps · pstree · kill  │
            └─────────────────────┘

  modules/dashboard.py — standalone, launched by either entry point.
  Owns its own process fetch/render/input loop (ProcessManager + Dashboard).
```

All path resolution (`source`, entry-point-to-entry-point calls) is relative to `${BASH_SOURCE[0]}`, not the caller's working directory — every script works the same whether invoked as `./monitor.sh`, via an absolute path, or via the `.deb`'s `/usr/bin` wrapper.

---

## Module Responsibilities

| Module | Responsibility |
|--------|-----------------|
| `monitor.sh` | CLI entry point. Renders the menu, reads a choice, dispatches via `input_module.sh`. |
| `monitor_gui.sh` | GUI entry point. Zenity radiolist loop; each action is handled inline, except thresholds, CSV export, and Credits text, which it sources from `monitor_module.sh`. Its `pick_pid()` helper builds a two-column Zenity process picker (reused by Kill/Suspend/Resume) and `show_report()` renders read-only text views. Module-level `ICON_ARGS` and `NO_MARKUP` arrays are splatted into every `zenity` call — see *Zenity markup safety* below. |
| `modules/monitor_module.sh` | `show_process_info`, `show_process_tree`, `search_process`, `show_alerts`, `export_csv`, `show_credits`, `colorize_line`, `launch_dashboard`. Also resolves `HIGH_THRESHOLD`/`MED_THRESHOLD` at source-time via the config-file precedence chain (see below). |
| `modules/manage_module.sh` | `kill_process`, `suspend_process`, `resume_process` — all validate the PID via the internal `_validate_pid` helper (numeric, and not the running session's own PID) before signaling. |
| `modules/input_module.sh` | `handle_user_input` — maps a CLI menu choice to the corresponding function. |
| `modules/dashboard.py` | `Process` (data holder), `ProcessManager` (fetch/filter/sort/signal/CSV-export via `ps`/`kill`), `Dashboard` (curses render + input loop: search, sort, export, kill, suspend, resume, quit — signal actions validated the same way as the Bash side via `_validate_pid`/`_apply_signal`). |

---

## Data Flow — Process Info

1. `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu` produces the sorted process table.
2. `colorize_line` inspects the last whitespace-separated field (`%CPU`) of each line, sanitizes it to digits-only, and wraps the line in an ANSI color code based on the configured thresholds.
3. The GUI's "Show Process Info"/"Search"/"Show Alerts" actions pipe the same `ps` output straight into a `zenity --text-info` dialog — no coloring, since Zenity's text widget does not render ANSI escapes. `PMM_MED_THRESHOLD` (the yellow cutoff) therefore has no effect in GUI mode; only `PMM_HIGH_THRESHOLD` (the alert cutoff) does.

## Data Flow — Signaling a Process (Kill/Suspend/Resume)

1. **CLI** (`manage_module.sh`) and **Live Dashboard** (`dashboard.py`) prompt for a PID directly.
2. **GUI** (`monitor_gui.sh`) instead builds a Zenity list via `pick_pid()` from `ps -eo pid,comm`, filtered to only suspended (`stat` contains `T`) processes for "Resume".
3. All three validate the PID before signaling: numeric, non-empty, and not equal to the running session's own PID or parent PID (self-suspend would otherwise freeze the session with no in-session recovery).
4. `kill -<SIGNAL> <pid>` is invoked as an argument list, never through shell string interpolation.

## Data Flow — Configuration Resolution

1. **Bash** (`monitor_module.sh`, sourced by both `monitor.sh` and `monitor_gui.sh`): captures any already-set `PMM_HIGH_THRESHOLD`/`PMM_MED_THRESHOLD` environment variables, `source`s `~/.config/process-monitor-manager/config` (`$XDG_CONFIG_HOME` respected) if it exists, then re-applies the captured environment variables on top — so a config-file value can never silently override an explicit invocation like `PMM_HIGH_THRESHOLD=80 ./monitor.sh`.
2. **Python** (`dashboard.py`'s `_load_threshold()`): the same three-tier precedence, implemented independently by reading the environment variable first, then scanning the config file line-by-line for a matching `KEY=` prefix, then falling back to the hardcoded default. Not shared code with the Bash side — the two runtimes don't share modules today (see Pulse's "Bash core, Python for stateful UI" note above).
3. Both readers only accept simple `KEY=VALUE` lines; the Bash side actually `source`s the file (so it's technically a snippet of Bash), while the Python side parses it as plain text and never executes it.

## Zenity Markup Safety

Zenity parses `--text` as [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) by default. That means any `&`, `<` or `>` in an interpolated value — a filesystem path like `.../Fully Tested & Deployed/...`, or a user-typed search query — aborts the dialog with a markup parse error instead of displaying.

Every `zenity --info`/`--error`/`--question` call therefore splats a module-level `NO_MARKUP=(--no-markup)` array. The single exception is the Credits dialog, which opts into markup for `<b>` and whose text is entirely literal (with `&` pre-escaped as `&amp;`) — no interpolation, so nothing user- or path-derived can reach the parser.

The two settings interact in a way that isn't obvious: **`--no-markup` also turns off `\n` escape handling.** A `--no-markup` dialog written with `\n` renders the backslash-n verbatim on screen, so those dialogs must embed real newlines instead. Markup dialogs still interpret `\n`. Both halves of this — markup off, and no literal `\n` where markup is off — are enforced by tests, because either failure is invisible until someone looks at the dialog.

`tests/smoke_test.sh` enforces this: it joins line-continuations, extracts each `zenity` invocation individually, and fails if any lacks `--no-markup` without being the Credits dialog. Extracting per-invocation rather than per-line matters — in an `a && b || c` chain, one safe call would otherwise mask an unsafe sibling on the same line.

## GUI Navigation

The GUI is a single loop around one radiolist menu; every action opens a sub-dialog and returns. Sub-dialogs therefore label their dismiss button **Back** (`--cancel-label="Back"`), and the main menu labels its own **Exit** — cancelling the top-level dialog leaves the app.

Read-only reports go through `show_report()`, which wraps `zenity --text-info`. Both its buttons read "Back": Zenity rejects `--no-cancel` for `--text-info`, so a single-button report isn't achievable, and both buttons dismiss identically anyway.

Zenity's handling of an unsupported flag is to print `<flag> is not supported for this dialog` to stderr and render the dialog *anyway* — a dropped Back button is therefore invisible from the script's side. `tests/smoke_test.sh` runs each dialog type with the flags the GUI actually passes and fails if Zenity reports any of them unsupported.

## Curses Sizing Rules

`dashboard.py` never reads `curses.LINES`/`curses.COLS`. Those are captured at `initscr` and go stale the moment the terminal is resized — measured: after a 24 → 10 row shrink they still reported 24, so a row loop sized from them wrote past the new last line, raised `curses.error`, and unwound the whole TUI.

Every write instead goes through `Dashboard._addstr()`, which re-reads `stdscr.getmaxyx()` per call, clips the text to the current width, skips out-of-range coordinates, and swallows `curses.error` as a backstop. Row counts use `max(0, height - 5)` — a plain `height - 5` goes negative on a very short terminal, and `processes[:-n]` silently drops rows from the *end* rather than showing none.

`tests/smoke_test.sh` drives `draw()` through real resizes inside a pty to keep this honest.

## CSV Export Failure Contract

`export_csv()` exists in two independent implementations (Bash and Python), and both must **fail loudly**, because the packaged `.deb` used to run every user out of a root-owned directory where writing always fails:

- **Bash** (`monitor_module.sh`) prints the filename and returns 0 on success; prints nothing and returns 1 on failure. Callers must branch on the exit status — printing the filename unconditionally is what made the original bug invisible.
- **Python** (`dashboard.py`) returns the filename, or `None` on `OSError`. It must not raise: an exception escaping the curses loop takes the entire dashboard down.

The Bash implementation deliberately avoids `if ! { … } > "$file"`. When a *redirection* fails, bash returns 1 for the whole construct and `!` does not invert it, so the negated form never fires.

## Icon Assets

Two SVGs, deliberately not one:

- **`assets/logo.svg`** (240×240) — the detailed README mark: window chrome, traffic-light dots, fine pulse line.
- **`assets/icon.svg`** (64×64, viewBox-only so it scales to any requested size) — what `monitor_gui.sh` actually passes to `zenity --icon`.

GTK renders a dialog icon at roughly 48px. At that size `logo.svg`'s 9-unit stroke in a 240-unit viewBox rasterizes to ~1.8px and its `r=10` dots to ~4px across — the artwork turns to mush. `icon.svg` drops the chrome and dots entirely and carries an 8-unit stroke in a 64-unit viewBox (~6px at 48px, over 3× bolder) spanning 84% of the canvas, keeping the pulse mark readable. `monitor_gui.sh` prefers `icon.svg` and falls back to `logo.svg`, then to no icon at all, so a partial install degrades rather than errors.

The 48px box is not adjustable: it's GTK's dialog-icon size, and Zenity 4.x exposes no flag for it (`--icon` takes a name/path only, and the `--html` text-info mode that could embed a sized `<img>` was removed after Zenity 3.x). The mark is therefore designed to fill that box, not to exceed it.

## Data Flow — Live Dashboard

1. `ProcessManager.fetch()` shells out to the same `ps` command and parses each line into a `Process` object. PID/PPID are taken as the first two tokens and `%MEM`/`%CPU` as the last two, so multi-word commands (with embedded flags/arguments) don't misalign the columns.
2. `Dashboard.run()` loops on a timer (`stdscr.timeout`), re-fetching, re-filtering (`ProcessManager.filter()`, substring match on command or PID), and re-sorting (`ProcessManager.sort()`, cycled via `o` between CPU/MEM/PID) on every refresh tick or keypress.
3. `e` calls `ProcessManager.export_csv()` on the currently filtered/sorted list — the Python equivalent of the Bash `export_csv()`, kept separate rather than shared since the two runtimes don't otherwise share code.
