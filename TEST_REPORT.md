# Carpet Studio test report

## Passed

- The macOS app bundle builds with Swift and has a valid ad-hoc signature.
- The app launched and its process remained running.
- A 1080 × 720 offscreen preview rendered the carpet.
- `./test.sh` passed checks for icon positions within the carpet and display, unique positions, rejection of an overfull layout, layout backup serialization, generated Finder AppleScript compilation, and distinct rendering of all four built-in styles.
- `Info.plist` passed validation, and the app ZIP passed archive integrity testing.
- The 0.2.0 app built as a universal `arm64` and `x86_64` binary targeting macOS 12 or later.
- The DMG checksum passed, and a read-only mount contained `Carpet Studio.app`, an `/Applications` shortcut, and installation instructions.
- The app's signature contains the Apple Events entitlement. Gatekeeper rejected the ad-hoc preview, as expected without a Developer ID signature and notarization.
- All build, test, DMG, and release scripts passed shell syntax checks. The public-release script correctly refused a missing Developer ID identity before any upload.

## Pending live checks

- Dragging, resizing, peeking, and menu selection on the actual desktop.
- Gathering Finder desktop icons and restoring their exact prior positions.
- Behavior when Finder Stacks or automatic sorting is enabled.

Codex computer control was not approved to access Carpet Studio, so those live UI checks could not be completed in this run. The current desktop icon layout was not changed during these tests. The app remains a development build until these interactions are verified.
