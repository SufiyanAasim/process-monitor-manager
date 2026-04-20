#!/bin/bash
# Bash syntax check + optional shellcheck + Python compile check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "== bash -n =="
bash -n monitor.sh monitor_gui.sh modules/*.sh scripts/*.sh tests/*.sh

if command -v shellcheck &>/dev/null; then
    echo "== shellcheck =="
    shellcheck monitor.sh monitor_gui.sh modules/*.sh scripts/*.sh tests/*.sh
else
    echo "shellcheck not installed — skipping (install with: sudo apt install shellcheck)"
fi

echo "== python3 -m py_compile =="
python3 -m py_compile modules/dashboard.py

echo "All checks passed."
