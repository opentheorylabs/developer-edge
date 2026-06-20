#!/usr/bin/env bash
# Package Developer Edge.app into a distributable DMG.
#
#   ./make-dmg.sh
#
# Produces DeveloperEdge.dmg with a drag-to-Applications layout.
# The app is ad-hoc signed (no paid Apple Developer account needed) so users
# can right-click → Open on first launch to get past Gatekeeper. For public
# distribution, sign with a Developer ID and notarize instead (see README).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Run from the repo root.
cd "$SCRIPT_DIR/.."

APP="Developer Edge.app"
VOL="Developer Edge"
DMG="DeveloperEdge.dmg"

# 1. Build the release .app (script lives in scripts/)
"$SCRIPT_DIR/make-app.sh"

# 2. Ad-hoc sign so Gatekeeper allows right-click → Open on first launch
echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

# 3. Stage a folder with the app + an Applications symlink (drag-to-install)
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 4. Build a compressed DMG
rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "Created $PWD/$DMG ($(du -h "$DMG" | cut -f1))"
echo "Share this file. Teammates: open the DMG, drag the app into Applications,"
echo "then right-click the app → Open the first time (unsigned app, Gatekeeper)."
