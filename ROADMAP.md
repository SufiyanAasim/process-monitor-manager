# Roadmap

## v5.0.0 — Beacon ✅ Shipped

- Deep bug/robustness audit: executable bits, location-dependent sourcing, GUI list columns, PID validation, self-signal protection, search-as-regex, and CI gaps.
- Credits screen (CLI + GUI, with a clickable "Open GitHub" button).
- Config-file support for alert/color thresholds (`~/.config/process-monitor-manager/config`).
- App icon in every Zenity dialog.

See [docs/releases/v5.0.0.md](docs/releases/v5.0.0.md) for the full list.

## v4.0.0 — Signal ✅ Shipped

- Configurable CPU/MEM alert thresholds via `PMM_HIGH_THRESHOLD`/`PMM_MED_THRESHOLD`.
- Interactive dashboard sorting (CPU/MEM/PID).
- CSV export (CLI, GUI, and dashboard).
- Packaged `.tar.gz` and `.deb` releases, automated via `.github/workflows/release.yml`.

## v5.1.0 — Unnamed (planned)

- `.rpm` packaging for Fedora/RHEL-based distributions.
- Interactive process-tree filtering (highlight/collapse by search match).
- Config-file schema validation (currently a malformed line is silently ignored).

## Ongoing

- `shellcheck`-clean CI on every push.
- Expanded manual test coverage across Debian-based distributions.

---

Roadmap items are subject to change. Check [CHANGELOG.md](CHANGELOG.md) for what has shipped.
