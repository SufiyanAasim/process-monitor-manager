<div align="center">

<img src="assets/logo.svg" alt="Process Monitor & Manager logo" width="110" />

# Process Monitor & Manager

**A lightweight terminal + GUI process monitor and manager for Ubuntu/Linux**

[![Bash](https://img.shields.io/badge/Bash-4.0%2B-4EAA25?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Version](https://img.shields.io/badge/version-4.0.0%20Signal-7c3aed?style=flat)](docs/releases/v4.0.0.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-22c55e?style=flat)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Linux-64748b?style=flat)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-0ea5e9?style=flat)](CONTRIBUTING.md)

Monitor, search, and manage system processes from a menu-driven CLI, a Zenity GUI, or a live auto-refreshing dashboard — no third-party dependencies beyond standard Linux tooling.

[**Changelog**](CHANGELOG.md) · [**Roadmap**](ROADMAP.md) · [**User Guide**](docs/guides/User-Guide.md) · [**Report a Bug**](.github/ISSUE_TEMPLATE/bug.yml)

</div>

---

## 📸 Screenshots

Not yet checked in — see [docs/images/](docs/images/) for how to add them. In the meantime, [docs/guides/User-Guide.md](docs/guides/User-Guide.md) shows the exact CLI menu and dashboard layout in text form.

---

## ✨ Features

### 📋 Process Info
- Top processes by CPU usage (`pid`, `ppid`, `cmd`, `%mem`, `%cpu`)
- Output color-coded by load — 🔴 ≥50%, 🟡 ≥20%, 🟢 below

### 🔎 Search
- Filter the process table by name or PID, CLI or GUI

### 🚨 Alerts
- One-shot report of every process currently above the CPU/MEM threshold (50% default, configurable)

### 📈 Live Dashboard
- Auto-refreshing, curses-based terminal UI (`modules/dashboard.py`)
- In-place search, and kill / suspend / resume without leaving the view

### 🌳 Process Tree
- Full hierarchy view via `pstree -p`

### 📤 CSV Export
- Snapshot the current process table to a timestamped `.csv` — CLI, GUI, or a keypress in the Live Dashboard

### 🔀 Configurable Thresholds & Sorting
- Alert/color thresholds overridable via `PMM_HIGH_THRESHOLD` / `PMM_MED_THRESHOLD` env vars
- Live Dashboard sorts by CPU, MEM, or PID — cycle with a keypress

### ⚙️ Process Control
- Kill, suspend (`SIGSTOP`), and resume (`SIGCONT`) any process you own

### 🖥️ Dual Interface
- Menu-driven CLI (`monitor.sh`) and a Zenity-based GUI (`monitor.sh --gui`) — same feature set, either way

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Entry Point                         │
│                     monitor.sh                          │
└────────────────┬──────────────┬──────────────────────────┘
                 │              │
     ┌───────────▼──────┐  ┌────▼──────────────────────┐
     │    CLI Mode       │  │       GUI Mode             │
     │   (monitor.sh)    │  │    (monitor_gui.sh)        │
     └───────────┬───────┘  └────────────┬───────────────┘
                 │                        │
     ┌───────────▼────────────────────────▼───────────────┐
     │                  modules/                           │
     │   monitor_module.sh  — info, search, alerts, tree   │
     │   manage_module.sh   — kill, suspend, resume         │
     │   input_module.sh    — CLI menu dispatch              │
     └───────────────────────┬────────────────────────────┘
                             │
                  ┌──────────▼──────────┐
                  │   ps · pstree · kill │
                  │   (procps, psmisc)   │
                  └─────────────────────┘

  modules/dashboard.py  ──►  ProcessManager + Dashboard classes
                              (curses live view, launched from either mode)
```

Full module breakdown in [docs/architecture/Architecture.md](docs/architecture/Architecture.md).

---

## 🛠️ Technology Stack

| Tool | Purpose |
|------|---------|
| `bash` | CLI entry point, menu, and module orchestration |
| `procps` (`ps`) | Process listing and sorting |
| `psmisc` (`pstree`) | Process hierarchy / tree view |
| `zenity` | GUI dialogs |
| `python3` (stdlib `curses` only) | Live auto-refreshing dashboard — no third-party packages |

No language runtime or package manager install is required beyond what's listed above — everything is standard Ubuntu tooling.

---

## 🚀 Getting Started

### Requirements
- Ubuntu or another Debian-based Linux distribution (or WSL with [WSLg](https://github.com/microsoft/wslg) for GUI mode)
- Bash and core-utils
- `make` is optional — only needed for the `make install`/`lint`/`test`/`run` shortcuts (`sudo apt install make`). The underlying `scripts/*.sh` and `tests/*.sh` work standalone without it.

### Install and run

```bash
git clone https://github.com/SufiyanAasim/process-monitor-manager.git
cd process-monitor-manager
./scripts/install-deps.sh   # or: make install
./monitor.sh
```

`scripts/install-deps.sh` runs `sudo apt install -y procps psmisc tree zenity` and makes the scripts executable. See [docs/deployment/Deployment.md](docs/deployment/Deployment.md) for manual steps, WSL setup, and other distributions — or skip cloning entirely and install a [packaged `.deb` or tarball](#-packaging--distribution) from the [Releases page](https://github.com/SufiyanAasim/process-monitor-manager/releases).

### Launch modes

```bash
./monitor.sh          # CLI menu           (or: make run)
./monitor.sh --gui     # Zenity GUI         (or: make run-gui)
```

From either mode, the **Live Dashboard** option launches `modules/dashboard.py` for a real-time, auto-refreshing view. Full walkthrough in [docs/guides/User-Guide.md](docs/guides/User-Guide.md).

---

## ⚙️ Configuration

No configuration files — the only runtime option is the `--gui` flag — but the alert/color thresholds are overridable via environment variables:

| Variable | Default | Description |
|----------|---------|--------------|
| `PMM_HIGH_THRESHOLD` | `50` | %CPU/%MEM at or above this shows red and counts as an alert |
| `PMM_MED_THRESHOLD` | `20` | %CPU at or above this shows yellow (CLI/GUI only — the dashboard uses `PMM_HIGH_THRESHOLD` for its red/yellow split too) |

```bash
PMM_HIGH_THRESHOLD=80 PMM_MED_THRESHOLD=40 ./monitor.sh
```

---

## 📦 Packaging & Distribution

There's no `.exe` equivalent for a Bash/Python Linux tool, but there are two real packaged-artifact options:

```bash
./scripts/package-release.sh 4.0.0   # or: make package VERSION=4.0.0
# → process-monitor-manager-v4.0.0.tar.gz — extract and run ./monitor.sh directly

./scripts/build-deb.sh 4.0.0         # or: make deb VERSION=4.0.0
# → process-monitor-manager_4.0.0_all.deb — sudo apt install ./process-monitor-manager_4.0.0_all.deb
#   installs a `process-monitor-manager` command on your PATH
```

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which builds both artifacts and attaches them to a GitHub Release automatically.

---

## 🐳 Docker & ☁️ Cloud Deployment

Not applicable. This tool inspects and signals *host* processes by PID — running it in a container would only see the container's own isolated processes, and there's no server component to deploy to the cloud. See [docs/deployment/Deployment.md](docs/deployment/Deployment.md#not-applicable-to-this-project) for the full reasoning.

---

## 🗂️ Project Structure

```
process-monitor-manager/
├── assets/
│   └── logo.svg               # Project logo
├── modules/
│   ├── monitor_module.sh    # Process info, search, alerts, tree, colorizing
│   ├── manage_module.sh     # Kill, suspend, resume
│   ├── input_module.sh      # CLI menu dispatch
│   └── dashboard.py         # ProcessManager + Dashboard classes (live TUI)
├── scripts/
│   ├── install-deps.sh      # apt install + chmod helper
│   ├── lint.sh                # bash -n + shellcheck + py_compile
│   ├── package-release.sh    # git-archive tarball for GitHub Releases
│   └── build-deb.sh           # builds a native .deb package
├── tests/
│   └── smoke_test.sh          # Functional sanity checks
├── docs/
│   ├── architecture/Architecture.md
│   ├── deployment/Deployment.md
│   ├── development/Development.md
│   ├── guides/User-Guide.md
│   ├── troubleshooting/Troubleshooting.md
│   ├── images/
│   └── releases/               # Per-version release notes
├── .github/
│   ├── ISSUE_TEMPLATE/         # Bug, feature, docs, question, security templates
│   ├── workflows/               # CI (lint) + release (package + publish on tag push)
│   ├── CODEOWNERS
│   └── dependabot.yml
├── monitor.sh                    # CLI entry point
├── monitor_gui.sh                 # GUI entry point (Zenity)
├── Makefile
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE
```

---

## 🧪 Testing

```bash
./scripts/lint.sh      # or: make lint  — bash -n, shellcheck, python compile check
./tests/smoke_test.sh   # or: make test  — module loading, signal handling, dashboard parsing
```

There's no unit-test framework here — the project is a thin wrapper over `ps`/`pstree`/`kill`, so `smoke_test.sh` asserts against real (self-spawned) processes instead.

---

## ⚡ Performance

`ps`/`pstree` calls dominate cost and scale with the OS's own process count, not with anything this tool does. The Live Dashboard re-fetches and re-renders on a fixed 2-second timer regardless of process count; there's no incremental diffing.

---

## 🌐 API Documentation

Not applicable — this is a local CLI/GUI tool with no network-facing API.

---

## ⌨️ Dashboard Shortcuts

| Key | Action |
|-----|--------|
| `/` | Search / filter by name or PID |
| `o` | Cycle sort order — CPU → MEM → PID |
| `e` | Export the current (filtered/sorted) view to CSV |
| `k` | Kill a process by PID |
| `s` | Suspend a process by PID |
| `r` | Resume a process by PID |
| `q` | Quit the dashboard |

---

## 🛡️ Security

Kill, suspend, and resume act with the permissions of the user running the script — no elevation is performed automatically. Managing processes you don't own requires running the tool with `sudo` yourself. See [SECURITY.md](SECURITY.md) to report a vulnerability.

---

## 🧩 Contributing

Bug reports, feature requests, and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and commit convention.

---

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for what's shipped and what's planned next.

---

## ❓ FAQ

**Does this work outside Ubuntu?** Any distro with GNU `procps`/`psmisc` works for CLI mode; GUI mode additionally needs `zenity` and a display (X11/Wayland/WSLg).

**Why isn't there a Windows-native version?** It shells out to `ps`, `pstree`, and POSIX signals (`SIGSTOP`/`SIGCONT`) — none of which exist natively on Windows. Use WSL.

**Can I change the 50%/20% alert and color thresholds?** Yes — set `PMM_HIGH_THRESHOLD` / `PMM_MED_THRESHOLD` before running (see the Configuration section above). There's no config-file option, only environment variables.

**Why does "Live Dashboard" do nothing in the GUI?** No terminal emulator was found — see [Troubleshooting](docs/troubleshooting/Troubleshooting.md#live-dashboard-gui-action-does-nothing).

---

## 🩺 Troubleshooting

See [docs/troubleshooting/Troubleshooting.md](docs/troubleshooting/Troubleshooting.md) for fixes to common issues (broken module paths, missing `pstree`/`zenity`, GUI dashboard launch failures, permission errors).

---

## 🙏 Acknowledgements

Built entirely on standard Linux tooling — [`procps`](https://gitlab.com/procps-ng/procps), [`psmisc`](https://gitlab.com/psmisc/psmisc), and [Zenity](https://gitlab.gnome.org/GNOME/zenity) — plus Python's standard-library `curses` for the live dashboard. No third-party packages.

---

## 💬 Support

See [SUPPORT.md](SUPPORT.md) for where to ask questions, report bugs, or get help.

---

## 🤝 Contributors

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/13eeCoder">
        <img src="https://github.com/13eeCoder.png" width="72" alt="13eeCoder"/><br/>
        <sub><b>Muhammad Taha Siddiqui</b></sub>
      </a><br/>
      <sub>Original Author · Core Bash Scripting</sub>
    </td>
    <td align="center">
      <a href="https://github.com/SufiyanAasim">
        <img src="https://github.com/SufiyanAasim.png" width="72" alt="SufiyanAasim"/><br/>
        <sub><b>Sufiyan Aasim</b></sub>
      </a><br/>
      <sub>Maintainer · Feature Development · Docs</sub>
    </td>
  </tr>
</table>

---

## 📄 License

[MIT License](LICENSE) © 2025-2026 Process Monitor & Manager Contributors.

---

<div align="center">

[Report Bug](.github/ISSUE_TEMPLATE/bug.yml) · [Request Feature](.github/ISSUE_TEMPLATE/feature.yml) · [Ask a Question](.github/ISSUE_TEMPLATE/question.yml)

</div>
