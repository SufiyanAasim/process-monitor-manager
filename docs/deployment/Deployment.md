# Deployment

Process Monitor & Manager is a local system tool, not a networked service — "deployment" here means installing it on a machine you'll run it on directly.

## Ubuntu / Debian-based Linux

```bash
git clone https://github.com/SufiyanAasim/process-monitor-manager.git
cd process-monitor-manager
./scripts/install-deps.sh
./monitor.sh
```

`scripts/install-deps.sh` installs `procps`, `psmisc`, `tree`, and `zenity` via `apt` and makes the scripts executable. See it in [scripts/install-deps.sh](../../scripts/install-deps.sh) if you'd rather run the steps manually.

## WSL (Windows)

1. Install WSL and an Ubuntu distro: `wsl --install -d Ubuntu` (from an elevated PowerShell/Terminal).
2. Modern WSL ships with [WSLg](https://github.com/microsoft/wslg), so GUI mode (`monitor.sh --gui`) renders directly on the Windows desktop — no extra X server needed.
3. Inside the Ubuntu shell, follow the **Ubuntu / Debian-based Linux** steps above. Access files under `D:\...` at `/mnt/d/...`.

See [docs/troubleshooting/Troubleshooting.md](../troubleshooting/Troubleshooting.md) if `wsl --install` or GUI rendering doesn't work out of the box.

## Other Linux distributions

The scripts depend on GNU `ps` (from `procps`, not BusyBox/toybox), `pstree` (from `psmisc`), and `zenity` for the GUI. Install the equivalent packages for your distribution's package manager and the CLI will work the same way; the GUI additionally needs a running X11/Wayland session.

## Not applicable to this project

- **Docker.** This tool inspects and signals *host* processes (`kill`, `SIGSTOP`/`SIGCONT` by PID). Running it inside a container would only expose the container's own isolated process namespace, defeating the point of the tool — so no `Dockerfile`/`docker-compose.yml` is provided.
- **Cloud deployment.** There is no server component; nothing here runs as a hosted service.
- **Environment variables / `.env`.** The tool takes no runtime configuration beyond CLI flags (`--gui`) and menu choices — see [ROADMAP.md](../../ROADMAP.md) for the planned configurable alert threshold.
