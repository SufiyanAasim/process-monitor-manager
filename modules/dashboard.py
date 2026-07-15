#!/usr/bin/env python3
"""Live process dashboard: auto-refreshing, searchable, color-coded by CPU/MEM."""

import curses
import datetime
import os
import subprocess


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
        return [p for p in processes if query in p.cmd.lower() or query == p.pid]

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
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"process_snapshot_{timestamp}.csv"
        with open(filename, "w", newline="") as f:
            f.write("PID,PPID,CMD,%MEM,%CPU\n")
            for p in processes:
                cmd = p.cmd.replace('"', '""')
                f.write(f'{p.pid},{p.ppid},"{cmd}",{p.mem},{p.cpu}\n')
        return filename


class Dashboard:
    REFRESH_SECONDS = 2
    HIGH_THRESHOLD = float(os.environ.get("PMM_HIGH_THRESHOLD", 50))
    MED_THRESHOLD = float(os.environ.get("PMM_MED_THRESHOLD", 20))

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

    def prompt(self, stdscr, label):
        curses.echo()
        stdscr.addstr(curses.LINES - 1, 0, " " * (curses.COLS - 1))
        stdscr.addstr(curses.LINES - 1, 0, label)
        stdscr.refresh()
        value = stdscr.getstr(curses.LINES - 1, len(label)).decode("utf-8").strip()
        curses.noecho()
        return value

    def draw(self, stdscr, processes):
        stdscr.erase()
        title = "Process Monitor - Live Dashboard  [/ search] [o sort] [e export] [k kill] [s suspend] [r resume] [q quit]"
        stdscr.addstr(0, 0, title[:curses.COLS - 1], curses.A_BOLD)
        stdscr.addstr(1, 0, f"Filter: {self.query or '(none)'}   Sort: {self.sort_field}   Refresh: {self.REFRESH_SECONDS}s")
        stdscr.addstr(2, 0, ProcessManager.HEADER[:curses.COLS - 1], curses.A_UNDERLINE)

        max_rows = curses.LINES - 5
        for i, proc in enumerate(processes[:max_rows]):
            stdscr.addstr(3 + i, 0, proc.row()[:curses.COLS - 1], self.color_for(proc.cpu))

        if self.message:
            stdscr.addstr(curses.LINES - 1, 0, self.message[:curses.COLS - 1])
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
                self.message = f"Exported to {filename}"
            elif key == ord('k'):
                pid = self.prompt(stdscr, "Kill PID: ")
                self.message = f"Killed {pid}" if self.manager.send_signal(pid, "TERM") else f"Failed to kill {pid}"
            elif key == ord('s'):
                pid = self.prompt(stdscr, "Suspend PID: ")
                self.message = f"Suspended {pid}" if self.manager.send_signal(pid, "STOP") else f"Failed to suspend {pid}"
            elif key == ord('r'):
                pid = self.prompt(stdscr, "Resume PID: ")
                self.message = f"Resumed {pid}" if self.manager.send_signal(pid, "CONT") else f"Failed to resume {pid}"


def main():
    manager = ProcessManager()
    dashboard = Dashboard(manager)
    curses.wrapper(dashboard.run)


if __name__ == "__main__":
    main()
