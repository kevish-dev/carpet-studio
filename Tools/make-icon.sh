#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
OUTPUT="${1:?Pass the output .icns path}"
mkdir -p build/AppIcon.iconset
swiftc -swift-version 5 -parse-as-library -framework AppKit Tools/GenerateIcon.swift -o build/icon-generator
build/icon-generator build/AppIcon-1024.png

for points in 16 32 128 256 512; do
    sips -z "$points" "$points" build/AppIcon-1024.png --out "build/AppIcon.iconset/icon_${points}x${points}.png" >/dev/null
    double=$((points * 2))
    sips -z "$double" "$double" build/AppIcon-1024.png --out "build/AppIcon.iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$OUTPUT"
