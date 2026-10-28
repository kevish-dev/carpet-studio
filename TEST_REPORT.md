# Carpet Studio 0.3.0 motion verification

The Mac app and browser demo now render a curved rug mesh with a patterned face, woven backing, bound edge and moving fringe. Pulling the upper-right corner continuously controls the curl. Releasing a drag lets a damped spring lay it down. Space/Return or the browser Lift Corner button holds it open. Both honor reduced motion.

## Passed

- Native app builds for arm64 and x86_64, macOS 12+. Info.plist is valid and the ad-hoc app signature verifies.
- Native mesh/normals are finite through 21 lift amounts; underside normals face the viewer at full curl; release spring settles.
- Native offscreen GPU snapshots of flat, half-lift and curled states inspected. All four styles render distinctly.
- Existing Finder layout boundary, uniqueness, crowded-desktop, backup serialization and AppleScript compilation checks pass. Finder icon positions were not changed in testing.
- Website: 21 Node tests pass. Coverage includes continuous bending, fabric length preservation, 5,000 randomized samples, 30/60/120 Hz spring stability, GPU buffer/texture lifecycle mocks, shader shared-uniform precision, pointer cancellation, multiple pointers, resize, reset, keyboard, reduced motion and WebGL fallback.
- Website input instrumentation: 100 pointermove events schedule one frame and make zero layout reads or DOM writes before that frame. Texture, markup and ARIA updates are kept outside pointermove.
- Native mesh topology/materials and web GPU buffers/textures are cached. Settled animation loops stop; the website pauses offscreen/in hidden tabs.
- Universal DMG checksum verification passed.

## Verification limits

Browser shader execution and live frame rate have not been measured. Browser control for the local origin and computer control for Carpet Studio were not approved earlier, so no alternate UI automation was used. Native visual checks use offscreen SceneKit rendering, not live desktop interaction. Drag/resize/menu handling and Finder Gather/Restore still need a manual desktop check.

This is a development preview. It is ad-hoc signed, not Developer ID signed or notarized.
