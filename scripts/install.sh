#!/usr/bin/env bash
# Builds Doppio, installs it to /Applications (or ~/Applications), and opens it.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

dest=/Applications
if [[ ! -w $dest ]]; then
    dest="$HOME/Applications"
    mkdir -p "$dest"
fi

# Quit a running copy first so the bundle can be replaced.
if pgrep -x Doppio >/dev/null; then
    osascript -e 'tell application id "local.doppio.Doppio" to quit' 2>/dev/null || pkill -x Doppio || true
    sleep 1
fi

rm -rf "$dest/Doppio.app"
cp -R build/Doppio.app "$dest/"
echo "Installed $dest/Doppio.app"
open "$dest/Doppio.app"
