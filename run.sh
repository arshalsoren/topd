#!/usr/bin/env bash
# Build topd (release), assemble topd.app, and start it in the background.
# topd runs as an app bundle, not a bare binary, because launch at login (SMAppService) needs one.
# There is no Dock icon and no window: look for topd in the menu bar after launch.
set -euo pipefail

cd "$(dirname "$0")"

if pgrep -x topd >/dev/null 2>&1; then
    echo "topd is already running. Look for it in the menu bar."
    echo "To restart it: pkill -x topd && ./run.sh"
    exit 0
fi

swift build -c release --product topd --quiet

APP=".build/topd.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/topd "$APP/Contents/MacOS/topd"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Ad-hoc signature: enough to run locally. Distribution needs a Developer ID signature and notarization.
codesign --force --sign - "$APP" >/dev/null 2>&1

open -g "$APP"

echo "topd started. Look for it in the menu bar."
echo "To stop it: pkill -x topd"
