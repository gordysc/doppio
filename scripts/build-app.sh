#!/usr/bin/env bash
# Builds build/Doppio.app: compiles a release binary and wraps it in an app bundle.
#
# Set CODESIGN_IDENTITY to sign with a real certificate; otherwise the app is
# ad-hoc signed, which is enough to run it on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

app_name=Doppio
app="build/$app_name.app"

swift build -c release
bin_dir=$(swift build -c release --show-bin-path)

[[ -f Resources/AppIcon.icns ]] || scripts/make-icon.sh

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/$app_name" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"

# "-" means ad-hoc: a signature with no certificate behind it.
codesign --force --options runtime --sign "${CODESIGN_IDENTITY:--}" "$app"
echo "Built $app"
