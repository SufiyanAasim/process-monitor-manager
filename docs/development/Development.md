# Development

## Prerequisites

- Ubuntu or another Debian-based Linux distribution (WSL + [WSLg](https://github.com/microsoft/wslg) works for GUI mode too)
- Bash 4.0+
- Python 3.8+ (standard library only — used for the live dashboard)

## Setup

```bash
git clone https://github.com/SufiyanAasim/process-monitor-manager.git
cd process-monitor-manager
./scripts/install-deps.sh
```

`scripts/install-deps.sh` installs `procps`, `psmisc`, `tree`, and `zenity` via `apt`, and makes the entry points and modules executable. See [Deployment.md](../deployment/Deployment.md) for manual steps or a non-Ubuntu target.

## Running from source

```bash
./monitor.sh                    # CLI menu
./monitor.sh --gui               # Zenity GUI
python3 modules/dashboard.py     # Live dashboard directly
```

## Sanity-checking changes

There is no automated unit-test suite (the project is a thin wrapper over `ps`/`pstree`/`kill`). Before submitting a change, run:

```bash
./scripts/lint.sh          # bash -n + shellcheck (if installed) + python compile check
./tests/smoke_test.sh       # basic functional sanity checks
```

## Building packaged releases

```bash
./scripts/package-release.sh 4.0.0   # requires the vX.Y.Z tag to already exist locally
./scripts/build-deb.sh 4.0.0          # requires dpkg-dev (sudo apt install dpkg-dev)
```

Both take a version string, not a tag name (no leading `v`). `package-release.sh` builds directly from the git tag via `git archive`, so tag the release before packaging it. See [RELEASE.md](../../RELEASE.md) for the full release process, and [Deployment.md](../deployment/Deployment.md) for how end users install the resulting artifacts.

## Project structure

```
process-monitor-manager/
├── assets/
│   └── logo.svg              # Project logo
├── modules/
│   ├── monitor_module.sh   # Process info, search, alerts, tree, colorizing
│   ├── manage_module.sh    # Kill, suspend, resume
│   ├── input_module.sh     # CLI menu dispatch
│   └── dashboard.py        # ProcessManager + Dashboard classes (live TUI)
├── scripts/
│   ├── install-deps.sh     # apt install + chmod helper
│   ├── lint.sh               # bash -n + shellcheck + py_compile
│   ├── package-release.sh   # git-archive tarball for GitHub Releases
│   └── build-deb.sh          # builds a native .deb package
├── tests/
│   └── smoke_test.sh        # Basic sanity checks
├── docs/
│   ├── architecture/Architecture.md
│   ├── deployment/Deployment.md
│   ├── development/Development.md
│   ├── guides/User-Guide.md
│   ├── troubleshooting/Troubleshooting.md
│   ├── images/
│   └── releases/
├── .github/
├── monitor.sh
├── monitor_gui.sh
├── Makefile
├── CHANGELOG.md
└── LICENSE
```

## Commit convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|--------|---------|
| `feat:` | New features |
| `fix:` | Bug fixes |
| `docs:` | Documentation only |
| `refactor:` | Code restructuring without behavior change |
| `perf:` | Performance improvements |
| `style:` | Formatting, whitespace — no logic change |
| `build:` | Packaging or dependency-install scripts |
| `ci:` | CI/CD configuration |
| `test:` | Test additions or fixes |
| `chore:` | Housekeeping, no source or test changes |
| `revert:` | Reverts a previous commit |

```
feat(dashboard): add CSV export shortcut
fix(gui): handle empty search query
docs(readme): update installation section
refactor(modules): extract color threshold constants
```

One commit per release (`release: v4.1.0 - <Codename>`). No noise commits for minor doc or config tweaks — stage everything into the release commit.

## Branch naming

```
main
release/v4.1.0
hotfix/search-empty-query
feature/csv-export
feature/dashboard-sorting
bugfix/dashboard-parsing
refactor/color-thresholds
docs/architecture-update
ci/lint-workflow
perf/dashboard-refresh
security/kill-signal-validation
```
