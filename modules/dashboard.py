#!/usr/bin/env python3
"""Live process dashboard: auto-refreshing, searchable, color-coded by CPU/MEM."""

import curses
import datetime
import os
import subprocess


def _config_file_path():
    config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return os.path.join(config_home, "process-monitor-manager", "config")


def _load_threshold(key, default):
    """Environment variable > config file (KEY=VALUE lines) > default."""
    env_value = os.environ.get(key)
    if env_value is not None:
        return float(env_value)

    path = _config_file_path()
    if os.path.isfile(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line.startswith(f"{key}="):
                    value = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if value:
                        return float(value)

    return float(default)


class Process:
    def __init__(self, pid, ppid, cmd, mem, cpu):
        self.pid = pid
        self.ppid = ppid
        self.cmd = cmd
        self.mem = mem
        self.cpu = cpu

    def row(self):
        return f"{self.pid:<8}{self.ppid:<8}{self.cmd:<40.40}{self.mem:>6}{self.cpu:>7}"


class ProcessManager:
    HEADER = f"{'PID':<8}{'PPID':<8}{'CMD':<40}{'%MEM':>6}{'%CPU':>7}"

    def fetch(self):
        result = subprocess.run(
            ["ps", "-eo", "pid,ppid,cmd,%mem,%cpu", "--sort=-%cpu"],
            capture_output=True, text=True, check=True,
        )
        processes = []
        for line in result.stdout.strip().splitlines()[1:]:
            parts = line.split()
            if len(parts) < 5:
                continue
            # PID/PPID are always the first two tokens and %MEM/%CPU the last
            # two; CMD is everything in between and may itself contain spaces.
            pid, ppid = parts[0], parts[1]
            mem, cpu = parts[-2], parts[-1]
            cmd = " ".join(parts[2:-2])
            processes.append(Process(pid, ppid, cmd, mem, cpu))
        return processes

    def filter(self, processes, query):
        if not query:
            return processes
        query = query.lower()
        return [p for p in processes if query in p.cmd.lower() or query in p.pid]

    SORT_FIELDS = ("cpu", "mem", "pid")

    def sort(self, processes, field):
        if field == "pid":
            return sorted(processes, key=lambda p: int(p.pid) if p.pid.isdigit() else 0)
        if field == "mem":
            return sorted(processes, key=lambda p: float(p.mem or 0), reverse=True)
        return sorted(processes, key=lambda p: float(p.cpu or 0), reverse=True)

    def send_signal(self, pid, sig):
        try:
            subprocess.run(["kill", f"-{sig}", str(pid)], check=True,
                            capture_output=True, text=True)
            return True
        except subprocess.CalledProcessError:
            return False

    def export_csv(self, processes):
        """Write a CSV snapshot to the working directory.

        Returns the filename, or None if it couldn't be written — an
        unwritable directory must not take the whole dashboard down with it.
        """
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"process_snapshot_{timestamp}.csv"
        try:
            with open(filename, "w", newline="") as f:
                f.write("PID,PPID,CMD,%MEM,%CPU\n")
                for p in processes:
                    cmd = p.cmd.replace('"', '""')
                    f.write(f'{p.pid},{p.ppid},"{cmd}",{p.mem},{p.cpu}\n')
        except OSError:
            return None
        return filename


class Dashboard:
    REFRESH_SECONDS = 2
    HIGH_THRESHOLD = _load_threshold("PMM_HIGH_THRESHOLD", 50)
    MED_THRESHOLD = _load_threshold("PMM_MED_THRESHOLD", 20)

    def __init__(self, manager):
        self.manager = manager
        self.query = ""
        self.message = ""
        self.sort_field = "cpu"

    def color_for(self, cpu):
        try:
            value = float(cpu)
        except ValueError:
            value = 0.0
        if value >= self.HIGH_THRESHOLD:
            return curses.color_pair(1)
        if value >= self.MED_THRESHOLD:
            return curses.color_pair(2)
        return curses.color_pair(3)

    def _validate_pid(self, pid):
        if not pid or not pid.isdigit():
            return False, f"Invalid PID: '{pid}' (must be a positive number)"
        if pid in (str(os.getpid()), str(os.getppid())):
            return False, f"Refusing to signal PID {pid} - that's this dashboard's own process"
        return True, ""

    def _apply_signal(self, pid, sig, verb):
        valid, error = self._validate_pid(pid)
        if not valid:
            return error
        if self.manager.send_signal(pid, sig):
            return f"{verb} {pid}"
        return f"Failed to {verb.lower()} {pid}"

    @staticmethod
    def _addstr(stdscr, y, x, text, attr=0):
        """Write text clipped to the window's *current* size.

        Deliberately re-reads getmaxyx() on every call rather than trusting
        curses.LINES/curses.COLS: those are captured at initscr and go stale
        the moment the terminal is resized, so writing rows based on them
        lands past the new last row and raises curses.error — killing the
        whole dashboard. The try/except is a backstop for the same reason.
        """
        height, width = stdscr.getmaxyx()
        if y < 0 or y >= height or x < 0 or x >= width:
            return
        clipped = text[:max(0, width - x - 1)]
        if not clipped:
            return
        try:
            stdscr.addstr(y, x, clipped, attr)
        except curses.error:
            pass

    def prompt(self, stdscr, label):
        height, width = stdscr.getmaxyx()
        curses.echo()
        try:
            self._addstr(stdscr, height - 1, 0, " " * width)
            self._addstr(stdscr, height - 1, 0, label)
            stdscr.refresh()
            return stdscr.getstr(height - 1, len(label)).decode("utf-8").strip()
        except curses.error:
            return ""
        finally:
            # Leaving echo on would corrupt every later keypress.
            curses.noecho()

    def draw(self, stdscr, processes):
        stdscr.erase()
        height, _ = stdscr.getmaxyx()

        title = ("Process Monitor - Live Dashboard  [/ search] [o sort] "
                 "[e export] [k kill] [s suspend] [r resume] [q quit]")
        self._addstr(stdscr, 0, 0, title, curses.A_BOLD)
        self._addstr(stdscr, 1, 0,
                     f"Filter: {self.query or '(none)'}   "
                     f"Sort: {self.sort_field}   Refresh: {self.REFRESH_SECONDS}s")
        self._addstr(stdscr, 2, 0, ProcessManager.HEADER, curses.A_UNDERLINE)

        # max(0, ...) matters: a terminal shorter than 5 rows would otherwise
        # make this negative, and processes[:-n] silently drops rows from the
        # end instead of showing none.
        max_rows = max(0, height - 5)
        for i, proc in enumerate(processes[:max_rows]):
            self._addstr(stdscr, 3 + i, 0, proc.row(), self.color_for(proc.cpu))

        if self.message:
            self._addstr(stdscr, height - 1, 0, self.message)
        stdscr.refresh()

    def run(self, stdscr):
        curses.curs_set(0)
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_RED, -1)
        curses.init_pair(2, curses.COLOR_YELLOW, -1)
        curses.init_pair(3, curses.COLOR_GREEN, -1)
        stdscr.nodelay(True)
        stdscr.timeout(self.REFRESH_SECONDS * 1000)

        while True:
            processes = self.manager.filter(self.manager.fetch(), self.query)
            processes = self.manager.sort(processes, self.sort_field)
            self.draw(stdscr, processes)

            key = stdscr.getch()
            if key == ord('q'):
                break
            elif key == ord('/'):
                self.query = self.prompt(stdscr, "Search: ")
                self.message = ""
            elif key == ord('o'):
                next_index = (ProcessManager.SORT_FIELDS.index(self.sort_field) + 1) % len(ProcessManager.SORT_FIELDS)
                self.sort_field = ProcessManager.SORT_FIELDS[next_index]
                self.message = f"Sorting by {self.sort_field}"
            elif key == ord('e'):
                filename = self.manager.export_csv(processes)
                self.message = (f"Exported to {filename}" if filename
                                else "Export failed - working directory is not writable")
            elif key == ord('k'):
                pid = self.prompt(stdscr, "Kill PID: ")
                self.message = self._apply_signal(pid, "TERM", "Killed")
            elif key == ord('s'):
                pid = self.prompt(stdscr, "Suspend PID: ")
                self.message = self._apply_signal(pid, "STOP", "Suspended")
            elif key == ord('r'):
                pid = self.prompt(stdscr, "Resume PID: ")
                self.message = self._apply_signal(pid, "CONT", "Resumed")


def main():
    manager = ProcessManager()
    dashboard = Dashboard(manager)
    curses.wrapper(dashboard.run)


if __name__ == "__main__":
    main()
