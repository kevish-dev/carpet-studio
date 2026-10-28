#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="build/Carpet Studio.app"
EXECUTABLE="$APP/Contents/MacOS/CarpetStudio"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/arch
cp Info.plist "$APP/Contents/Info.plist"

for architecture in arm64 x86_64; do
    swiftc -swift-version 5 -O -target "${architecture}-apple-macos12.0" \
        -framework AppKit -framework CoreGraphics Sources/*.swift \
        -o "build/arch/CarpetStudio-${architecture}"
done
lipo -create build/arch/CarpetStudio-arm64 build/arch/CarpetStudio-x86_64 -output "$EXECUTABLE"

Tools/make-icon.sh "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${CARPET_SIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$CARPET_SIGN_IDENTITY" --options runtime --timestamp \
        --entitlements Entitlements.plist "$APP"
else
    codesign --force --sign - --options runtime --entitlements Entitlements.plist "$APP"
fi

codesign --verify --deep --strict "$APP"
echo "$PWD/$APP"
