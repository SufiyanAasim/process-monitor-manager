# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 3.x     | Yes       |
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
- No data is transmitted over a network — all functionality is local process inspection and signaling.
- `modules/dashboard.py` uses only the Python standard library — no third-party packages, no external network calls.
