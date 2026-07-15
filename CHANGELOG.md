# Changelog

All notable changes to Process Monitor & Manager are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

> Pre-release. Initial handoff from the original author — not restructured or verified against a clean environment.

### Added
- Initial project scaffold: `monitor.sh` (CLI entry point), `monitor_gui.sh` (Zenity GUI), and three module scripts covering process info, process control, and CLI input handling.
- Core capabilities: show process info, kill/suspend/resume a process by PID, show process tree, and a mirrored Zenity GUI.

---

[4.0.0]: docs/releases/v4.0.0.md
[3.0.0]: docs/releases/v3.0.0.md
[2.0.0]: docs/releases/v2.0.0.md
[1.0.0]: docs/releases/v1.0.0.md
