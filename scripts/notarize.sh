#!/usr/bin/env bash
# Build, Developer ID-sign, notarize, and staple Developer Edge into a DMG for
# public distribution. Requires a paid Apple Developer account.
#
# Required environment variables:
#   DEV_ID      "Developer ID Application: Your Name (TEAMID)"
#   KEYCHAIN_PROFILE   name of a notarytool keychain profile you created once via:
#       xcrun notarytool store-credentials KEYCHAIN_PROFILE \
#         --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
# Usage: DEV_ID="Developer ID Application: ..." KEYCHAIN_PROFILE=de ./scripts/notarize.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

: "${DEV_ID:?set DEV_ID to your Developer ID Application identity}"
: "${KEYCHAIN_PROFILE:?set KEYCHAIN_PROFILE to your notarytool credential profile}"

APP="Developer Edge.app"
DMG="DeveloperEdge.dmg"
VOL="Developer Edge"

# 1. Build the release .app
"$SCRIPT_DIR/make-app.sh"

# 2. Sign with hardened runtime (required for notarization)
echo "Signing with $DEV_ID ..."
codesign --force --deep --options runtime --timestamp --sign "$DEV_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# 3. Stage + build the DMG
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# 4. Notarize the DMG and staple the ticket
echo "Submitting to Apple notary service..."
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "Notarized $PWD/$DMG ($(du -h "$DMG" | cut -f1))"
echo "Compute the SHA for the Homebrew cask with: shasum -a 256 $DMG"
