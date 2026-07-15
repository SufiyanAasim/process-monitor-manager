# Troubleshooting

## `./monitor.sh`: No such file or directory (module sourcing fails)

Two distinct causes, both fixed by now:

- **Missing `modules/` directory or `.sh` extension** — fixed in [v2.0.0](../releases/v2.0.0.md). Confirm the three module scripts live under `modules/` with a `.sh` extension:
  ```bash
  ls modules/
  # monitor_module.sh  manage_module.sh  input_module.sh
  ```
- **Running the script via a path other than `./monitor.sh` from the repo root** (e.g. `bash /some/other/path/monitor.sh`, or a symlink on `PATH`) — fixed in [v5.0.0](../releases/v5.0.0.md). Module paths now resolve relative to the script's own location, not the caller's working directory. Make sure you're on `v5.0.0` or later.

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

---

## `Invalid PID: '...' (must be a positive number)`

The PID you entered wasn't empty or numeric — re-enter using the numeric PID shown in "Show Process Info" or "Search Process", not the process name.

---

## `Refusing to signal PID <pid> — that's this session's own shell/process`

Kill/Suspend/Resume (CLI, GUI, and Live Dashboard) refuse to target the running session's own process — suspending your own shell would freeze the session with no in-session way to resume it. This is expected behavior, not a bug; target a different process's PID.

---

## `dpkg-deb not found` when running `scripts/build-deb.sh`

Install the Debian packaging tools:
```bash
sudo apt install dpkg-dev
```

---

## Threshold environment variables don't seem to change anything

`PMM_HIGH_THRESHOLD`/`PMM_MED_THRESHOLD` must be set in the same shell invocation that runs the script — exporting them beforehand works too, but a `sudo ./monitor.sh` run in a different shell/session won't see variables set only in your regular user shell (`sudo` doesn't inherit your environment by default):
```bash
PMM_HIGH_THRESHOLD=80 ./monitor.sh          # OK
export PMM_HIGH_THRESHOLD=80 && ./monitor.sh # also OK
sudo PMM_HIGH_THRESHOLD=80 ./monitor.sh      # OK — passes it through to sudo explicitly
```

---

## Config file changes don't seem to apply

Two likely causes:

- **An environment variable is already set** and always overrides the config file — check `echo "$PMM_HIGH_THRESHOLD $PMM_MED_THRESHOLD"` in the same shell; unset them (`unset PMM_HIGH_THRESHOLD PMM_MED_THRESHOLD`) to let the config file take effect.
- **Wrong path.** The config file must be at `~/.config/process-monitor-manager/config`, or `$XDG_CONFIG_HOME/process-monitor-manager/config` if you've set `XDG_CONFIG_HOME`. Confirm with:
  ```bash
  ls "${XDG_CONFIG_HOME:-$HOME/.config}/process-monitor-manager/config"
  ```

---

## GUI dialogs don't show the project icon

Zenity needs `librsvg` (or an equivalent SVG loader) installed to render `assets/icon.svg` as a window icon — most desktop-complete Ubuntu installs already have it via GTK's dependencies. This fails silently (no error, just no icon) rather than breaking the dialog, so it's cosmetic only.

If `assets/icon.svg` is missing, the GUI falls back to `assets/logo.svg`, then to no icon. `logo.svg` is the detailed README artwork and looks noticeably muddier at icon size — that's expected, and why `icon.svg` exists.

---

## "Export to CSV" says it worked but there's no file

Fixed in [v5.0.0](../releases/v5.0.0.md). Earlier versions never checked whether the write succeeded and reported success either way. This bit `.deb` installs hardest: the packaged wrapper `cd`'d into the root-owned install directory, so the export failed every single time. On `v5.0.0`+ you'll get a real error naming the directory instead — `cd` somewhere writable and retry.

---

## The Live Dashboard vanishes when I resize the terminal

Fixed in [v5.0.0](../releases/v5.0.0.md). Earlier versions sized their output from `curses.LINES`/`curses.COLS`, which don't update on resize, so shrinking the window made the dashboard draw past the last row and abort.

---

## "Live Dashboard" in the GUI does nothing on Ubuntu

Fixed in [v5.0.0](../releases/v5.0.0.md). The launcher passed `-e python3 <path>` to whatever terminal it found; `gnome-terminal` (which `x-terminal-emulator` usually points to on Ubuntu) only accepts a single string after `-e`, so the launch failed — silently, since it runs in the background. If you're on `v5.0.0`+ and it still does nothing, run the dashboard directly to see the real error:

```bash
python3 modules/dashboard.py
```

---

## A GUI dialog flashes and disappears, or never opens

If a dialog aborts with `Failed to set text ... from markup due to error parsing markup` on stderr, an interpolated value (usually a filesystem path) contains `&`, `<` or `>`, which Zenity parses as Pango markup. Fixed in [v5.0.0](../releases/v5.0.0.md) — every value-interpolating dialog now passes `--no-markup`. If you hit this on an older version, moving the checkout to a path without an ampersand works around it.

---

## "Open GitHub" button in Credits does nothing

`xdg-open` isn't installed. Install it with:
```bash
sudo apt install xdg-utils
```
Or copy the GitHub URL shown in the Credits text and open it manually.
