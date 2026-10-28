#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

: "${CARPET_SIGN_IDENTITY:?Set CARPET_SIGN_IDENTITY to a Developer ID Application certificate name.}"
: "${CARPET_NOTARY_PROFILE:?Set CARPET_NOTARY_PROFILE to a notarytool Keychain profile name.}"
[[ "$CARPET_SIGN_IDENTITY" == "Developer ID Application:"* ]] || {
    echo "Public releases require a Developer ID Application certificate." >&2
    exit 1
}
security find-identity -v -p codesigning | grep -Fq "$CARPET_SIGN_IDENTITY" || {
    echo "Developer ID Application certificate is not installed in the Keychain." >&2
    exit 1
}

./build.sh
DMG="dist/Carpet-Studio-0.2.0-macOS.dmg"
./package-dmg.sh "$DMG"
codesign --force --sign "$CARPET_SIGN_IDENTITY" --timestamp "$DMG"
RESPONSE="dist/notarization-response.json"
xcrun notarytool submit "$DMG" --keychain-profile "$CARPET_NOTARY_PROFILE" --wait --output-format json > "$RESPONSE"
SUBMISSION_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$RESPONSE")"
xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$CARPET_NOTARY_PROFILE" 'dist/notarization-log.json'
STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")"
[[ "$STATUS" == "Accepted" ]] || { echo "Notarization status: $STATUS; see dist/notarization-log.json" >&2; exit 1; }
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
codesign --verify "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
spctl --assess --type execute --verbose=2 'build/Carpet Studio.app'
echo "Public release ready: $PWD/$DMG"
