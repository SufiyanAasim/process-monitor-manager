# Troubleshooting

## `./monitor.sh`: No such file or directory (module sourcing fails)

Fixed in [v2.0.0](../releases/v2.0.0.md) — make sure you're on `v2.0.0` or later. If you still hit this, confirm the three module scripts live under `modules/` with a `.sh` extension:
```bash
ls modules/
# monitor_module.sh  manage_module.sh  input_module.sh
```

---

## `ps: unknown option -- o` / `ps: unrecognized option '--sort'`

You're running on a non-GNU `ps` (e.g. Cygwin/BusyBox on Windows). This project targets GNU `procps`, available on Ubuntu and other standard Linux distributions. On native Windows, use WSL — see [README → Requirements](../../README.md#requirements).

---

## `pstree: command not found`

Install `psmisc`:
```bash
sudo apt install psmisc
```

---

## GUI mode does nothing / `zenity: command not found`

Install Zenity:
```bash
sudo apt install zenity
```
On WSL, GUI apps require [WSLg](https://github.com/microsoft/wslg) (built into modern `wsl --install`). Run `wsl --version` and confirm a `WSLg version` line is present; if not, run `wsl --update`.

---

## "Live Dashboard" GUI action does nothing

The GUI launches the dashboard inside a terminal emulator. If none of `x-terminal-emulator`, `gnome-terminal`, `konsole`, `xfce4-terminal`, or `xterm` is installed, the action shows an error instead of failing silently. Install one, e.g.:
```bash
sudo apt install xterm -y
```
Or run the dashboard directly from a terminal you already have open:
```bash
python3 modules/dashboard.py
```

---

## Dashboard columns look misaligned

Make sure you're on `v3.0.0` or later — earlier dashboard builds mis-parsed multi-word commands (see [CHANGELOG](../../CHANGELOG.md)). If it persists, your terminal window may be narrower than the rendered row width; widen the terminal.

---

## `Failed to kill/suspend/resume process <pid>`

You most likely don't own that process. Re-run the tool with `sudo` to manage processes owned by other users:
```bash
sudo ./monitor.sh
```
