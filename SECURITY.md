# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 5.x     | Yes       |
| 4.x     | No        |
| 3.x     | No        |
| 2.x     | No        |
| 1.x     | No        |

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities privately by emailing:

**sufiyanaasim@outlook.com**

Include in your report:
- A clear description of the vulnerability.
- Steps to reproduce or a proof-of-concept.
- The potential impact.
- Your suggested fix, if any.

You will receive a response within 7 days. If the vulnerability is confirmed, a patch will be released as a priority and you will be credited in the release notes unless you prefer to remain anonymous.

## Security model

- Kill, suspend, and resume run as the invoking user — no privilege escalation is performed by the scripts. Managing processes you don't own requires the user to invoke the tool with `sudo` themselves.
- PID and search input is passed to `kill`/`ps`/`grep` without shell evaluation (no `eval`, no unquoted expansion into a command context).
- PID input is validated as numeric before being signaled, and Kill/Suspend/Resume refuse to target the running session's own process — across the CLI, GUI, and Live Dashboard.
- No data is transmitted over a network — all functionality is local process inspection and signaling. The Credits screen's "Open GitHub" button opens a hardcoded repository URL via `xdg-open`; it never sends data anywhere.
- **The threshold config file (`~/.config/process-monitor-manager/config`) is loaded with Bash `source`, not parsed as plain key-value data.** Only place `PMM_HIGH_THRESHOLD=`/`PMM_MED_THRESHOLD=` assignments in it, the same as you would in a `.bashrc` — anyone who can write to that path can already run code as you, so this doesn't introduce a new trust boundary, but don't copy an untrusted config file into place.
- `modules/dashboard.py` uses only the Python standard library — no third-party packages, no external network calls.
