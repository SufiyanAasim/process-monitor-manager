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
v5.1.0
Codename: <Name>
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
## [5.1.0] — "Codename" — YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
### Security
```

---

## 4. Write the release doc

Create `docs/releases/v5.1.0.md` using [v5.0.0.md](docs/releases/v5.0.0.md) as a template. Include: codename, overview, objectives, categorized change list (with an emoji + title subsection per notable item), architecture progress notes, known limitations, a compatibility table, and contributors. Close with **🚀 What's Next** if another version is already planned, or **🏁 Release Summary** if this is the current shipped release with nothing next in active development. Update the previous release doc's own closing section from **🏁 Release Summary** to **🚀 What's Next** now that it's no longer the latest.

---

## 5. Sanity-check and package

```bash
./scripts/lint.sh
./tests/smoke_test.sh
```

All checks must pass before tagging. There's no need to manually build the release artifacts (`.tar.gz`/`.deb`) — pushing the tag does that automatically (step 7).

---

## 6. Commit and tag

```bash
git add -A
git commit -m "release: v5.1.0 - Codename"
git tag v5.1.0
git push origin main --tags
```

Include co-authors in the commit message if applicable:
```
release: v5.1.0 - Codename

Co-authored-by: Contributor Name <their-github-registered-email@example.com>
```

---

## 7. GitHub release

Pushing the `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which builds the `.tar.gz` (`scripts/package-release.sh`) and `.deb` (`scripts/build-deb.sh`), then publishes a GitHub Release with both attached and `docs/releases/v<Version>.md` as the description.

To verify: navigate to the GitHub Releases page, confirm both artifacts are attached, and spot-check one by downloading and running it.

---

## 8. Update ROADMAP.md

Mark the shipped version as ✅ Shipped and promote the next planned version.
