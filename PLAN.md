# Carpet Studio — macOS app plan

## Product goal

Place a movable, customizable carpet over desktop icons. The carpet changes only what is visible; files and folders remain in their original locations on disk. An optional command gathers Finder desktop icons beneath the carpet and can restore their prior layout.

## Initial feature plan

1. A carpet appears above Finder's desktop icons and below ordinary app windows.
2. Drag the carpet anywhere on the desktop; resize it from a corner.
3. Lift a corner to reveal icons, then release it to cover them again.
4. Choose among built-in carpet styles or import a custom image.
5. Adjust carpet opacity, shadow, and size. Save the appearance and position across launches.
6. Gather all desktop icons under the carpet, with a one-click Restore command.
7. Run from the menu bar, with controls to show, hide, reset, and quit.
8. Later: realistic cloth physics, icon-shaped bulges, multiple carpets, per-display layouts, and optional automatic gathering rules.

## Review and revisions before building

- **Desktop safety:** Gathering changes only Finder icon positions. It must save a durable snapshot before changing anything, provide Restore, and avoid overwriting an existing snapshot. A quit command should restore a gathered layout by default.
- **Permission handling:** Mac Automation permission is only needed when the user chooses Gather or Restore. A permission failure must leave the rug useful as a visual cover and show a clear error.
- **Layout constraints:** Finder's automatic sorting and Stacks can override manual positions. The app should detect or explain this before gathering, rather than silently claiming success.
- **Interaction clarity:** Dragging the body moves the rug; dragging the upper-right corner lifts it; dragging the lower-right handle resizes it. These zones must be visually distinct.
- **Customization:** Start with built-in styles, imported image, opacity, and shadow. Add rotation and multiple carpets after the window behavior and reversible Finder operation are proven.
- **Display scope:** First build targets the main desktop. Secondary displays require a follow-up implementation for per-display carpet state and Finder coordinates.

## Build 1 acceptance criteria

- Launches as a menu bar Mac app without a Dock icon.
- Rug can move, resize, lift/release, hide/show, and change style.
- Custom image import works, and settings survive relaunch.
- Gather saves the original icon positions before arranging them near the rug center; Restore puts them back.
- Build succeeds with Xcode command-line tools and produces a runnable `.app` bundle.

## Later work

- Multi-display support and multiple independent carpets.
- More physical fold animation and optional icon bumps.
- Drag-to-sweep gesture, layouts/presets, keyboard shortcuts, accessibility and localization polish.
- Signed and notarized release packaging.

## Build 1 status

Implemented: a menu bar app, four built-in patterns, custom image import, opacity and shadow controls, drag to move, drag to resize, corner peek, saved appearance and position, and a Finder icon gathering flow with a durable position backup and Restore.

Verified: Swift compilation, app bundle signature, both Finder AppleScript commands compile, the app process launches, an offscreen 1080 × 720 render shows the carpet, and automated smoke tests pass for layout bounds, icon uniqueness, crowded layouts, snapshot serialization, and all four built-in renders. Live mouse interaction and Finder icon gathering/restore have not been exercised against the user's current desktop; Codex computer control was not approved for this newly built app.

## Distribution build status

Version 0.2.0 adds a first-run guide, permission instructions, a custom app icon, a universal Apple silicon and Intel binary with macOS 12 minimum, an Apple Events entitlement, a drag-to-Applications DMG, and a Developer ID / notarization release script. The DMG currently produced on this Mac is an ad-hoc signed preview. A Developer ID Application certificate and a notarization Keychain profile are still required for a public Gatekeeper-approved release.
