# Roadmap

## v4.0.0 — Signal ✅ Shipped

- Configurable CPU/MEM alert thresholds via `PMM_HIGH_THRESHOLD`/`PMM_MED_THRESHOLD`.
- Interactive dashboard sorting (CPU/MEM/PID).
- CSV export (CLI, GUI, and dashboard).
- Packaged `.tar.gz` and `.deb` releases, automated via `.github/workflows/release.yml`.

## v4.1.0 — Unnamed (planned)

- Config-file option for thresholds, as an alternative to environment variables.
- `.rpm` packaging for Fedora/RHEL-based distributions.
- Interactive process-tree filtering (highlight/collapse by search match).

## Ongoing

- `shellcheck`-clean CI on every push.
- Expanded manual test coverage across Debian-based distributions.

---

Roadmap items are subject to change. Check [CHANGELOG.md](CHANGELOG.md) for what has shipped.
