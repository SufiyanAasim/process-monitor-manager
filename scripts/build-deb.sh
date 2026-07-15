#!/bin/bash
# Builds a .deb package for native installation on Debian-based systems
# (sudo apt install ./process-monitor-manager_<version>_all.deb).
# Requires dpkg-deb (package: dpkg-dev).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

VERSION="${1:?Usage: build-deb.sh <version, e.g. 5.0.0>}"
PKG_NAME="process-monitor-manager"

if ! command -v dpkg-deb &>/dev/null; then
    echo "dpkg-deb not found. Install it with: sudo apt install dpkg-dev" >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d)"
STAGE="$BUILD_DIR/${PKG_NAME}_${VERSION}"
trap 'rm -rf "$BUILD_DIR"' EXIT

mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/lib/$PKG_NAME/modules" "$STAGE/usr/lib/$PKG_NAME/assets" "$STAGE/usr/bin"

cp monitor.sh monitor_gui.sh "$STAGE/usr/lib/$PKG_NAME/"
cp modules/*.sh modules/*.py "$STAGE/usr/lib/$PKG_NAME/modules/"
cp assets/*.svg "$STAGE/usr/lib/$PKG_NAME/assets/"
chmod +x "$STAGE/usr/lib/$PKG_NAME"/*.sh "$STAGE/usr/lib/$PKG_NAME/modules"/*.sh

# No 'cd' here on purpose. Up to v4.0.0 the wrapper had to cd into the install
# directory because monitor.sh sourced its modules relative to the working
# directory; v5.0.0 resolves them from ${BASH_SOURCE[0]} instead, so the cd is
# both unnecessary and harmful — it dropped the user into a root-owned
# directory, which is where "Export to CSV" would then try (and fail) to write.
# Running from the user's own working directory puts the CSV where they expect.
cat > "$STAGE/usr/bin/$PKG_NAME" <<WRAPPER
#!/bin/bash
exec "/usr/lib/$PKG_NAME/monitor.sh" "\$@"
WRAPPER
chmod +x "$STAGE/usr/bin/$PKG_NAME"

cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), procps, psmisc, python3
Recommends: zenity, tree
Maintainer: Sufiyan Aasim <sufiyanaasim@outlook.com>
Description: Terminal + GUI process monitor and manager
 Menu-driven CLI and Zenity GUI for inspecting, searching, and
 managing (kill/suspend/resume) Linux processes, plus a live
 auto-refreshing dashboard.
CONTROL

OUT="$SCRIPT_DIR/${PKG_NAME}_${VERSION}_all.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$OUT"

echo "Built $OUT"
echo "Install with: sudo apt install $OUT"
