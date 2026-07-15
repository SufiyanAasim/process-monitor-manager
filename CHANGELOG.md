# Changelog

All notable changes to Process Monitor & Manager are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.0.0] — "Beacon" — 2026-07-15

### Added
- **Credits.** CLI option 10 and a GUI "Credits" action listing both members with their role, GitHub handle, and contact email. The GUI gives each member their own button — "GitHub: @SufiyanAasim" and "GitHub: @13eeCoder" — opening that profile via `xdg-open`, falling back to `wslview` (WSL, where `xdg-open` usually isn't installed) and then to showing the URL.
- **Code ownership is now explicit.** `.github/CODEOWNERS` and a README ownership table record the split: `modules/manage_module.sh` (process control — kill/suspend/resume and PID validation) belongs to [@13eeCoder](https://github.com/13eeCoder); everything else — CLI, GUI, Live Dashboard, packaging, CI, docs — to [@SufiyanAasim](https://github.com/SufiyanAasim).
- **Config-file support for thresholds.** `PMM_HIGH_THRESHOLD`/`PMM_MED_THRESHOLD` can now be set persistently in `~/.config/process-monitor-manager/config` (`$XDG_CONFIG_HOME` respected) instead of exporting an environment variable every time — an explicit environment variable still overrides the config file. See `config/process-monitor-manager.example`. Read consistently by the Bash modules and `dashboard.py`.
- **App icon in the GUI.** A new `assets/icon.svg` is passed to every Zenity dialog via `--icon`, so the project mark shows in the window/taskbar instead of a generic icon. It's a separate, simplified asset from `assets/logo.svg`: GTK renders dialog icons at ~48px, where the logo's 9-unit stroke in a 240-unit viewBox rasterizes to ~1.8px and its detail turns to mush. `icon.svg` uses a 64-unit viewBox with an 8-unit stroke (~6px at 48px, over 3× bolder) spanning 84% of the canvas, and drops the window chrome and traffic-light dots entirely. `monitor_gui.sh` falls back to `logo.svg`, then to no icon, if either is missing. Both are now included in the `.deb` package staging, which previously omitted `assets/` entirely. Note that the ~48px box itself is a GTK dialog-icon constant — Zenity exposes no way to enlarge it, so the mark is drawn to fill that box rather than to escape it.
- **Back buttons throughout the GUI.** Sub-dialogs (process pickers, the search prompt, Credits) now label their dismiss button "Back" instead of "Cancel", making it clear they return to the main menu rather than aborting the app; the main menu's own cancel is labelled "Exit". Read-only reports render via a new shared `show_report()` helper and label both buttons "Back", since Zenity rejects `--no-cancel` for `--text-info` and both buttons do the same thing. `tests/smoke_test.sh` verifies Zenity actually honours these flags rather than silently ignoring them.
- `tests/smoke_test.sh` gained coverage for PID validation, self-signal protection, fixed-string search matching, the dashboard's partial-PID filtering, Credits content, config-file precedence, Zenity markup safety, icon-asset validity, GUI Back buttons, CSV-export failure handling, the `.deb` wrapper's working directory, dashboard survival across a terminal resize (driven through a real pty), role/ownership attribution, and pre-release consistency between the release notes and the release workflow — 34 checks total, up from 8. Each new guard was verified by reverting the fix and confirming the test fails.

### Changed
- **Breaking: CLI menu renumbered again.** "10. Credits" was inserted ahead of Exit, which moves from `10` to `11` — the same category of break `v4.0.0` introduced for the same reason (a new option ahead of Exit). This is why this release is `v5.0.0` rather than a `v4.1.0`/patch: menu-position breaks are treated as MAJOR regardless of how the feature itself is scoped.
- **Roles corrected.** Earlier releases credited [@13eeCoder](https://github.com/13eeCoder) as Original Author and [@SufiyanAasim](https://github.com/SufiyanAasim) as Maintainer. That was backwards: Sufiyan Aasim is the project's author and maintainer, and Muhammad Taha Siddiqui is a contributor, responsible for process control. Corrected in the README, `LICENSE`, `CODEOWNERS`, both Credits screens, and the `v1.0.0` release notes.
- **Contact details.** Sufiyan Aasim: `sufiyanaasim@outlook.com` (used for `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, the security issue template, and the `.deb` maintainer field). Muhammad Taha Siddiqui: `tahasiddiqui2100@gmail.com`. Both appear on the Credits screens.
- `modules/monitor_module.sh`'s `export_csv()` now prints only the output filename (not a full sentence), so it can be reused as-is by both the CLI and the GUI instead of each reimplementing the same CSV-writing `awk` logic.
- `monitor_gui.sh` now sources `modules/monitor_module.sh` directly rather than duplicating its threshold and CSV-export logic.
- `monitor_gui.sh`'s "Suspend a Process" and "Resume a Process" now use the same process-picker list as "Kill a Process" instead of requiring manual PID entry — "Resume" filters the list to only currently-suspended processes. This also removes a redundant second `ps` invocation each in "Search a Process" and "Show Alerts".
- CLI failure messages now consistently end in a period, matching the success messages.
- `scripts/package-release.sh` now checks the target tag exists locally before attempting `git archive`, with a clear error instead of git's raw failure.
- `.github/workflows/release.yml` now explicitly `chmod +x`'s the scripts before running them, as defense-in-depth against the executable-bit issue recurring.

### Fixed
- **Executable bits were never committed to git.** `core.filemode=false` in the working environment meant every `chmod +x` was silently dropped when staging — all scripts were tracked as `100644` (non-executable) in every prior commit. A fresh `git clone` on Linux would need a manual `chmod +x` before anything ran, and `.github/workflows/release.yml`'s `./scripts/*.sh` calls would fail outright on a CI runner. Fixed by explicitly setting the executable bit in the git index for every script.
- **`monitor.sh` broke when invoked from outside the repo root.** `source modules/...` and `bash ./monitor_gui.sh` were resolved relative to the current working directory, not the script's own location — the same class of bug `v2.0.0` fixed, just relocated. Both now resolve relative to `${BASH_SOURCE[0]}`, so `bash /any/path/monitor.sh` works from any directory.
- **`monitor_gui.sh`'s "Kill a Process" list was a single merged column.** `--column="PID:Command"` (one string) doesn't define two Zenity columns; each row rendered as a raw `"1234:bash"` string, and selecting one required manually `cut`-ting the PID back out. Replaced with a real two-column list (`--column="PID" --column="Command" --print-column=1`) that returns just the PID directly.
- **Live Dashboard PID search was inconsistent with the CLI/GUI.** Searching by PID required an *exact* match (`query == pid`) while the CLI/GUI matched PID as a substring like any other field. The dashboard now matches PID substrings too.
- **Dashboard/CLI/GUI signal actions had no input validation.** Empty, non-numeric, or self-referential (the tool's own shell/process PID) input was passed straight to `kill`, producing a raw shell error or — for a self-targeted `SIGSTOP` — freezing the interactive session with no easy recovery. Kill/Suspend/Resume in the CLI, GUI, and Live Dashboard now validate the PID and refuse to signal the running session's own process.
- **Search treated the query as a regex, not literal text.** `grep -i` meant characters like `.` or `*` in a search term matched unintentionally (e.g. `a.b` also matching `aXb`). Switched to `grep -iF` (fixed-string) in the CLI and GUI, matching the dashboard's plain substring search.
- **`colorize_line` could throw a bash arithmetic error** on a non-integer `%CPU` value (e.g. a locale that renders decimals with a comma). The value is now sanitized to digits-only before the `(( ))` comparison.
- **`--window-icon` is deprecated in current Zenity** (4.x) — the GUI icon integration uses `--icon` instead, which is the maintained flag.
- **Any `&`, `<` or `>` in an interpolated Zenity dialog aborted that dialog.** Zenity parses `--text` as Pango markup by default, so a path containing an ampersand (e.g. a checkout under `.../Fully Tested & Deployed/...`) or a search query with a metacharacter produced `Failed to set text ... from markup due to error parsing markup` and the dialog never appeared. Every value-interpolating dialog now passes `--no-markup`; only the static Credits text (with `&` pre-escaped) still opts into markup. `tests/smoke_test.sh` now enforces this per-invocation.
- **`--no-markup` also disables `\n` handling, so the fix above initially made those dialogs print a literal `\n` on screen.** Multi-line text in a `--no-markup` dialog must carry real newlines; all five affected dialogs now do. Markup dialogs (Credits) still interpret `\n` and are unaffected. Guarded by a test, since the two flags interact invisibly.
- **The GUI's window close (X) button did nothing.** Cancelling or closing the main radiolist fell through to a `*)` branch that ran `continue`, immediately reopening the same dialog — the only way out was picking "Exit" from the list. Cancel and X now exit, and the cancel button is labelled "Exit" to match.
- **"Export to CSV" reported success for a file it never wrote.** `export_csv()` never checked whether its output redirection succeeded, so in a directory it couldn't write to it returned exit 0 and printed a filename anyway — the CLI then said "Exported current process snapshot to …" and the GUI showed a success dialog, with no file on disk. It now returns non-zero and prints nothing on failure, and both callers report the error instead. (The first attempt at this fix was itself broken: `if ! { …; } > "$outfile"` never fires, because bash returns 1 for the whole construct when the *redirection* fails and the `!` does not invert it. Rewritten as an `if`/`else` with no negation.)
- **Every `.deb` install had CSV export broken, always.** The packaged `usr/bin` wrapper ran `cd /usr/lib/process-monitor-manager` before launching, dropping the user into a root-owned directory — exactly where "Export to CSV" then tried and failed to write. That `cd` was a workaround for the relative-module-sourcing bug *this same release fixes*, so it is now both unnecessary and harmful; the wrapper `exec`s the absolute path instead, and the CSV lands in the user's own working directory.
- **An unwritable directory crashed the Live Dashboard.** `dashboard.py`'s `export_csv()` let `open()`'s `PermissionError` propagate out of the curses loop, tearing down the whole TUI. It now returns `None` and the dashboard shows an "Export failed" status line.
- **Resizing the terminal crashed the Live Dashboard.** `draw()` sized its output from `curses.LINES`/`curses.COLS`, which are captured at `initscr` and go stale on resize — verified: after a 24→10 row shrink, `curses.LINES` still reported 24 while the window was really 10, so the row loop wrote past the last line and raised `curses.error`. All drawing now clips against a live `stdscr.getmaxyx()`, guards against terminals shorter than the header, and swallows `curses.error` as a backstop.
- **The GUI's Live Dashboard failed to launch on standard Ubuntu desktops.** It invoked `$TERMINAL -e python3 <path>`, passing three separate arguments. `xterm` and `konsole` accept that, but `gnome-terminal` and `xfce4-terminal` take only a single string after `-e` (and gnome-terminal's `-e` is deprecated), leaving the path as a stray argument — and `x-terminal-emulator`, the first candidate tried, is usually a symlink to `gnome-terminal` on Ubuntu. Because the launch is backgrounded, the failure never reached a dialog. The launcher now resolves `x-terminal-emulator` to its real target and passes the documented flag for each terminal (`--` for gnome-terminal, `-x` for xfce4-terminal, `-e` otherwise).
- `modules/monitor_module.sh` declared and assigned `local outfile="…$(date …)"` in one statement (ShellCheck SC2155), which masks the command's return value — CI runs ShellCheck, so this would have failed the build.
- **Pre-release status was documentation-only.** `CHANGELOG.md` and the releases index both called `v1.0.0` a pre-release, but `docs/releases/v1.0.0.md` never said so itself, and `.github/workflows/release.yml` had no `prerelease` flag at all — pushing that tag would have published it on GitHub as a full release. The release note now carries the marker, and the workflow derives `prerelease` by grepping for it rather than hardcoding, so the notes and the published release can't disagree. Both halves are test-guarded.
- **The GUI's "Open GitHub" button dead-ended under WSL.** It only tried `xdg-open`, which isn't installed on a default WSL Ubuntu — the very environment the docs recommend most. URL opening now tries `xdg-open`, then `wslview`, then falls back to showing the URL.
- **README incorrectly documented `PMM_MED_THRESHOLD`.** First found to claim the Live Dashboard reused `PMM_HIGH_THRESHOLD` for its yellow cutoff (the dashboard has always read `PMM_MED_THRESHOLD` correctly). A follow-up documentation pass then found the *corrected* text was still imprecise — `PMM_MED_THRESHOLD` genuinely has **no effect in GUI mode**, since Zenity's text widget never color-codes at all (only the alert cutoff, `PMM_HIGH_THRESHOLD`, applies there). README, `docs/guides/User-Guide.md`, and `docs/architecture/Architecture.md` now state this precisely.
- **`docs/architecture/Architecture.md` was stale.** Still described the CLI and GUI as fully independent with no shared code, missing `monitor_gui.sh`'s new `pick_pid()` helper and its sourcing of `monitor_module.sh`, and missing `export_csv`/sorting/PID-validation from the module and dashboard responsibility tables.
- **`docs/troubleshooting/Troubleshooting.md` and the README FAQ didn't cover the new validation/self-protection error messages** (`Invalid PID: ...`, `Refusing to signal PID ...`) introduced by the hardening work folded into this release, or the "invoked from outside the repo root" instance of the module-sourcing error.
- **`SECURITY.md`'s supported-versions table still said `3.x`** after `4.0.0` had already shipped.
- **`.github/PULL_REQUEST_TEMPLATE.md` referenced pre-`v3.0.0` manual test commands** (`bash -n ...`, `python3 -m py_compile ...`) instead of the `scripts/lint.sh`/`tests/smoke_test.sh` wrappers that have existed since `v3.0.0`.
- **`.github/ISSUE_TEMPLATE/bug.yml`'s version placeholder and several commit/branch-name examples in `CONTRIBUTING.md`/`docs/development/Development.md` referenced already-shipped work** (CSV export, dashboard sorting) as if it were still pending, and an old `3.0.0` version placeholder.
- **CI's `bash -n` syntax check omitted `scripts/*.sh` and `tests/*.sh`**, unlike the local `scripts/lint.sh`, leaving the packaging scripts and test suite itself unchecked in CI.
- **`.github/workflows/release.yml` was missing `permissions: contents: write`**, which `softprops/action-gh-release` needs to create a release — would fail with a 403 on any repo with restrictive default `GITHUB_TOKEN` permissions.

---

## [4.0.0] — "Signal" — 2026-07-15

### Added
- **Configurable alert/color thresholds.** `PMM_HIGH_THRESHOLD` and `PMM_MED_THRESHOLD` environment variables override the 50%/20% defaults across the CLI, GUI, and Live Dashboard.
- **Interactive dashboard sorting.** Press `o` in the Live Dashboard to cycle sorting by CPU, MEM, or PID.
- **CSV export.** Snapshot the current process table to a timestamped `.csv` — CLI option 9, GUI "Export to CSV", or `e` in the Live Dashboard.
- **Packaged releases.** `scripts/package-release.sh` (git-archive tarball) and `scripts/build-deb.sh` (native `.deb` via `dpkg-deb`), wired into `.github/workflows/release.yml` so pushing a `v*` tag builds and attaches both to a GitHub Release automatically.
- `make package VERSION=x.y.z` and `make deb VERSION=x.y.z` Makefile targets.

### Changed
- **Breaking: CLI menu renumbered.** `monitor.sh`'s menu gained a "9. Export to CSV" option ahead of Exit, which moved from `9` to `10`. Any script or muscle-memory piping `9` into the CLI to exit will now trigger a CSV export instead — hence the major version bump.
- `monitor_gui.sh` radiolist extended with an "Export to CSV" action.

---

## [3.0.0] — "Pulse" — 2026-04-20

### Added
- **Search Process.** Filter the process table by name or PID from the CLI menu (option 6) and the GUI ("Search a Process").
- **High CPU/MEM Alerts.** One-shot report of every process currently at or above the 50% CPU/MEM threshold — CLI option 7 and GUI "Show Alerts".
- **Live Dashboard.** `modules/dashboard.py` — a curses-based, auto-refreshing terminal UI with in-place search and kill/suspend/resume, built around two classes: `ProcessManager` (fetch/filter/signal) and `Dashboard` (rendering and input loop). Launched from CLI option 8 or the GUI "Live Dashboard" action.
- **Colorized process output.** CLI process listings are now color-coded by CPU load — red (≥50%), yellow (≥20%), green (below).
- Full open-source repository structure: `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `ROADMAP.md`, `RELEASE.md`, a topic-based `docs/` hierarchy (`architecture/`, `deployment/`, `development/`, `guides/`, `troubleshooting/`, `images/`, `releases/`), and `.github/` (bug/feature/docs/question/security issue templates, PR template, `CODEOWNERS`, `dependabot.yml`, and a lint CI workflow).
- `scripts/install-deps.sh` and `scripts/lint.sh`, plus `tests/smoke_test.sh` — functional sanity checks that run against real self-spawned processes (module loading, signal handling, colorizing thresholds, dashboard parsing).
- `Makefile` (`install`/`lint`/`test`/`run`/`run-gui`), `.editorconfig`, and `.gitattributes` (forces LF line endings on shell scripts — a CRLF shebang breaks execution on Linux).
- `docs/deployment/Deployment.md` and `docs/guides/User-Guide.md`.
- `assets/logo.svg` — project logo, shown at the top of the README.

### Changed
- `monitor.sh` menu reordered to include the three new CLI options ahead of Exit.
- `monitor_gui.sh` radiolist extended with Search, Alerts, and Live Dashboard actions alongside the original four.
- `Commands Used` folded into [docs/development/Development.md](docs/development/Development.md) and removed as a standalone file.
- `docs/Architecture.md`, `docs/Development.md`, and `docs/Troubleshooting.md` moved into their own topic subdirectories (`docs/architecture/`, `docs/development/`, `docs/troubleshooting/`).

### Fixed
- `modules/dashboard.py`'s process-line parser now correctly handles multi-word commands (e.g. `python3 -m http.server 8000`) instead of misaligning the `%MEM`/`%CPU` columns.

---

## [2.0.0] — "Bedrock" — 2026-01-15

### Fixed
- **Broken module path.** `monitor.sh` sourced `modules/monitor_module.sh`, `modules/manage_module.sh`, and `modules/input_module.sh`, but the three module files shipped at the repository root as `monitor_module`, `manage_module`, and `input_module` — no `modules/` directory and no `.sh` extension. CLI mode failed immediately on launch. Moved all three into `modules/` with the expected `.sh` extension and made them executable.

### Verified
- CLI mode (`./monitor.sh`) — menu loop, Show Process Info, Show Process Tree, Kill/Suspend/Resume — confirmed working end-to-end on Ubuntu (WSL).
- GUI mode (`./monitor.sh --gui`) — Zenity dialogs confirmed rendering and functioning via WSLg.

---

## [1.0.0] — "Spark" — 2025-11-10

> Pre-release. Internal development milestone — not restructured or verified against a clean environment, and not publicly distributed.

### Added
- Initial project scaffold: `monitor.sh` (CLI entry point), `monitor_gui.sh` (Zenity GUI), and three module scripts covering process info, process control, and CLI input handling.
- Core capabilities: show process info, kill/suspend/resume a process by PID, show process tree, and a mirrored Zenity GUI.

---

[5.0.0]: docs/releases/v5.0.0.md
[4.0.0]: docs/releases/v4.0.0.md
[3.0.0]: docs/releases/v3.0.0.md
[2.0.0]: docs/releases/v2.0.0.md
[1.0.0]: docs/releases/v1.0.0.md
