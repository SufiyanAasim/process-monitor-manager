# Release Process

This document describes how to cut a new release of Process Monitor & Manager.

---

## 1. Decide version and codename

Use [Semantic Versioning](https://semver.org/):

| Change type | Bump |
|-------------|------|
| Breaking change | MAJOR |
| New feature | MINOR |
| Bug fix only | PATCH |

Codenames follow a single consistent theme across all releases.

Format:
```
v3.1.0
Codename: Signal
```

---

## 2. Update version references

Update the version string in:
- `README.md` — version badge
- `CHANGELOG.md` — new section header and footer reference link
- `docs/releases/README.md` — add the new entry at the top of the list

---

## 3. Write the changelog entry

Add a new section to `CHANGELOG.md` following the [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [3.1.0] — "Signal" — YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
### Security
```

---

## 4. Write the release doc

Create `docs/releases/v3.1.0.md` using [v3.0.0.md](docs/releases/v3.0.0.md) as a template. Include: codename, overview, objectives, categorized change list (with an emoji + title subsection per notable item), architecture progress notes, known limitations, a compatibility table, and contributors. Close with **🚀 What's Next** if another version is already planned, or **🏁 Release Summary** if this is the current shipped release with nothing next in active development.

---

## 5. Sanity-check the scripts

```bash
bash -n monitor.sh monitor_gui.sh modules/*.sh
python3 -m py_compile modules/dashboard.py
shellcheck monitor.sh monitor_gui.sh modules/*.sh
```

All checks must pass before tagging.

---

## 6. Commit and tag

```bash
git add -A
git commit -m "release: v3.1.0 - Signal"
git tag v3.1.0
git push origin main --tags
```

Include co-authors in the commit message if applicable:
```
release: v3.1.0 - Signal

Co-authored-by: Contributor Name <their-github-registered-email@example.com>
```

---

## 7. GitHub release

Create a GitHub release from the pushed tag, using the corresponding `docs/releases/v<Version>.md` file as the description.

---

## 8. Update ROADMAP.md

Mark the shipped version as ✅ Shipped and promote the next planned version.
