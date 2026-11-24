#!/usr/bin/env bash
# Builds build/Doppio.app: compiles a release binary and wraps it in an app bundle.
#
# Environment variables (all optional):
#   VERSION            Version string for the bundle, e.g. 1.2.0. Default: the one in Resources/Info.plist.
#   BUILD_NUMBER       Build number for the bundle. Default: 1.
#   UNIVERSAL=1        Build for both Apple silicon and Intel. Default: this Mac's architecture only.
#   CODESIGN_IDENTITY  Certificate to sign with. Default: "-", an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

app_name=Doppio
app="build/$app_name.app"
version=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}
build_number=${BUILD_NUMBER:-1}

arch_flags=()
if [[ ${UNIVERSAL:-0} == 1 ]]; then
    arch_flags=(--arch arm64 --arch x86_64)
fi

# `${arr[@]+"${arr[@]}"}` expands to nothing for an empty array. A plain
# "${arr[@]}" is an "unbound variable" error under `set -u` in macOS's bash 3.2.
swift build -c release ${arch_flags[@]+"${arch_flags[@]}"}
bin_dir=$(swift build -c release ${arch_flags[@]+"${arch_flags[@]}"} --show-bin-path)

[[ -f Resources/AppIcon.icns ]] || scripts/make-icon.sh

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/$app_name" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"

# Stamp the version into the bundle's copy of Info.plist, not the source one.
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $build_number" \
    "$app/Contents/Info.plist"

# "-" means ad-hoc: a signature with no certificate behind it.
codesign --force --options runtime --timestamp=none --sign "${CODESIGN_IDENTITY:--}" "$app"
echo "Built $app ($version, build $build_number)"
