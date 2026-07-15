#!/bin/bash
# Packages a versioned source tarball for GitHub Releases — the Bash/Linux
# equivalent of a packaged .exe zip, built straight from a git tag so it only
# contains tracked files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

VERSION="${1:?Usage: package-release.sh <version, e.g. 4.0.0>}"
PKG_NAME="process-monitor-manager"
OUT="${PKG_NAME}-v${VERSION}.tar.gz"

git archive --format=tar.gz --prefix="${PKG_NAME}-v${VERSION}/" -o "$OUT" "v${VERSION}"

echo "Built $SCRIPT_DIR/$OUT"
