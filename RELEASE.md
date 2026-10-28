# Carpet Studio distribution

## Current status

The project produces a universal macOS 12+ app and a drag-to-Applications DMG. The local preview DMG is ad-hoc signed. It is **not a public release**: macOS Gatekeeper rejects the app because this Mac has no Developer ID Application certificate installed.

## Public release prerequisites

1. An active Apple Developer Program team with a **Developer ID Application** certificate installed in the signing Keychain. An Apple Development certificate cannot be used for this release.
2. A `notarytool` Keychain profile for that team. Store it locally with `xcrun notarytool store-credentials`; keep the password or API private key out of the repository and chat.
3. Live validation of the carpet controls and Finder Gather/Restore on a test desktop, including permission denial and recovery. Codex computer control was not approved for this newly built app during the initial test.

## Build a public DMG

Set `CARPET_SIGN_IDENTITY` to the full Developer ID Application certificate name and `CARPET_NOTARY_PROFILE` to the stored Keychain profile name. Then run `./release.sh` from this folder. The script checks the certificate, builds both CPU architectures, signs with hardened runtime and the Finder Automation entitlement, creates and signs the DMG, submits it to Apple, staples the notarization ticket, and runs local verification.

The result is `dist/Carpet-Studio-0.3.0-macOS.dmg`. Publish that file only after the script succeeds and the live validation above passes.

## Installer experience

Users open the DMG, drag Carpet Studio to Applications, eject the DMG, and open the app. Its controls live in the menu bar. The first-run guide explains moving, resizing, peeking, and the optional Gather command. Covering icons requires no special permission. Gather and Restore use macOS Automation to control Finder; the system prompts only when those commands are used. If denied, users can grant access later in System Settings → Privacy & Security → Automation.

## Apple references

- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events
