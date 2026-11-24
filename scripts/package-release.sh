#!/usr/bin/env bash
# Builds a universal Doppio.app and packs it into a drag-to-install disk image.
#
# Usage: scripts/package-release.sh <version>      e.g. scripts/package-release.sh 1.2.0
#
# Output:
#   build/Doppio-<version>.dmg          Doppio.app plus a shortcut to /Applications
#   build/Doppio-<version>.dmg.sha256   SHA-256 checksum of the disk image
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:?usage: scripts/package-release.sh <version>}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: version must look like 1.2.3, got '$version'" >&2
    exit 1
fi

UNIVERSAL=1 VERSION=$version scripts/build-app.sh

# Lay out the disk image contents in a scratch folder: the app, and a symlink
# to /Applications so people can drag one onto the other.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R build/Doppio.app "$stage/"
ln -s /Applications "$stage/Applications"

dmg_name="Doppio-$version.dmg"
# UDZO is a compressed, read-only image: the usual format for downloads.
# macOS 27 marks `hdiutil create` deprecated in favour of `diskutil image`, but
# the macOS 15 CI runner may not have the replacement, so keep hdiutil for now.
hdiutil create -volname "Doppio $version" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "build/$dmg_name" >/dev/null

# Run from build/ so the checksum file names the bare file, which makes
# `shasum -c` work in whatever folder the user downloads both files to.
(cd build && shasum -a 256 "$dmg_name" > "$dmg_name.sha256")
echo "Packaged build/$dmg_name"
