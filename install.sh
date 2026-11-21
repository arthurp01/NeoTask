#!/usr/bin/env bash
# Install or update the NeoTask widget in the user's Plasma packages.
set -euo pipefail

cd "$(dirname "$0")"

# Technical package ID kept for compatibility with existing tasks.
PACKAGE_ID="io.github.arthurp01.neotask"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 was not found. Install kf6-kpackage (or plasma-desktop)." >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$PACKAGE_ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade .
    echo "NeoTask updated."
else
    kpackagetool6 --type Plasma/Applet --install .
    echo "NeoTask installed."
fi

echo
echo "To add it: right-click the desktop → Enter Edit Mode →"
echo "Add Widgets → search for “NeoTask”."
echo
echo "If an older version is already on the desktop, remove and re-add it"
echo "(or restart plasmashell) to reload the interface."
