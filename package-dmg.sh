#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="build/Carpet Studio.app"
OUTPUT="${1:-dist/Carpet-Studio-0.3.0-macOS.dmg}"
[[ -d "$APP" ]] || { echo "Build the app first with ./build.sh" >&2; exit 1; }
codesign --verify --deep --strict "$APP"
mkdir -p "${OUTPUT:h}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Carpet Studio.app"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.txt "$STAGE/Read Me.txt"
hdiutil create -srcfolder "$STAGE" -volname "Carpet Studio" -format UDZO -ov "$OUTPUT" >/dev/null
hdiutil verify "$OUTPUT" >/dev/null
echo "$PWD/$OUTPUT"
