#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/tests
swiftc -swift-version 5 -framework AppKit -framework CoreGraphics \
    Sources/FinderLayout.swift Sources/Preferences.swift Sources/RugCloth.swift Sources/RugView.swift Sources/RugWindow.swift \
    Tests/SmokeTests.swift -o build/tests/SmokeTests
build/tests/SmokeTests
