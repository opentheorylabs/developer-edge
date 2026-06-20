#!/usr/bin/env bash
# Package Zuperior Developer Edge.app into a distributable DMG for the team.
#
#   ./make-dmg.sh
#
# Produces ZuperiorDeveloperEdge.dmg with a drag-to-Applications layout.
# The app is ad-hoc signed (no paid Apple Developer account needed) so teammates
# can right-click → Open on first launch to get past Gatekeeper.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Run from the repo root.
cd "$SCRIPT_DIR/.."

APP="Zuperior Developer Edge.app"
VOL="Zuperior Developer Edge"
DMG="ZuperiorDeveloperEdge.dmg"

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
