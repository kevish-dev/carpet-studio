# Carpet Studio

A first-build macOS menu bar app that places a movable carpet over Finder's desktop icons. Files remain where they are on disk.

## Build and run

Requires Xcode Command Line Tools or Xcode.

```sh
./build.sh
open "build/Carpet Studio.app"
./test.sh
```

The app appears in the menu bar. Drag the carpet body to move it, its lower-right corner to resize it, and its upper-right corner inward to peek beneath it. Use the menu to choose a style, import an image, adjust opacity, or gather and restore icons.

Gather Icons changes Finder's desktop icon positions, saves their prior positions to Application Support first, and restores them when you choose Restore or quit normally. macOS may request permission to control Finder. Turn off Finder's Use Stacks and set Sort By to None before gathering.

The app is built as a universal Apple silicon and Intel binary for macOS 12 or later. The first build targets the main display. See [PLAN.md](PLAN.md) for the reviewed feature plan and later work.

## Installable disk image

Run `./package-dmg.sh` after building. The DMG contains the app, an Applications shortcut, and installation instructions. The default build is ad-hoc signed and intended for local preview only; macOS Gatekeeper rejects it as a normal public release.

For public distribution, install a **Developer ID Application** certificate and store notarization credentials in a `notarytool` Keychain profile, then run `./release.sh` with `CARPET_SIGN_IDENTITY` and `CARPET_NOTARY_PROFILE` set. The release script signs the universal app with the hardened runtime and Apple Events entitlement, creates and signs the DMG, submits it to Apple for notarization, staples the ticket, and verifies the result. Do not send a private key or account password in chat. See [RELEASE.md](RELEASE.md).

See [TEST_REPORT.md](TEST_REPORT.md) for the verification performed and the remaining live desktop checks.
