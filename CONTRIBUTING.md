# Contributing

Thank you for your interest in Process Monitor & Manager. Contributions are welcome — please read this guide before opening a pull request.

---

## Getting started

1. Fork the repository and clone your fork.
2. Install dependencies: `./scripts/install-deps.sh`
3. Sanity-check the scripts: `./scripts/lint.sh`
4. Create a branch: `git checkout -b feature/your-feature-name`

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

**Examples:**
```
feat(dashboard): add CSV export shortcut
fix(gui): handle empty search query
docs(readme): update installation section
```

## Pull request guidelines

- Keep PRs focused — one feature or fix per PR.
- Run `./scripts/lint.sh` and `./tests/smoke_test.sh` before submitting.
- Fill in the pull request template fully.
- Reference any related issues with `Closes #n`.

## Code style

- Bash: 4-space indentation, `snake_case` function names, `readonly` for constants.
- Python: follow PEP 8; the dashboard uses only the standard library — do not add third-party dependencies without discussion.
- No commented-out code in submitted PRs.
- Keep comments to the minimum needed to explain *why*, not *what*.

## Reporting bugs

Use the Bug Report issue template. Include:
- Distribution and version (e.g. Ubuntu 22.04, or WSL + distro).
- Steps to reproduce.
- Expected vs. actual behavior.
- Any relevant error output.

## Security vulnerabilities

Do **not** open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md).
