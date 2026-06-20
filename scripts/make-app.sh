#!/usr/bin/env bash
# Build Zuperior Developer Edge.app, a macOS menu bar app for the Zuperior trading platform.
#
#   ./make-app.sh            build "Zuperior Developer Edge.app" in this folder
#   ./make-app.sh --install  also copy it to /Applications and launch it
#
set -euo pipefail
# Run from the repo root regardless of where this script lives.
cd "$(dirname "$0")/.."

echo "Building release binary..."
swift build -c release

APP="Zuperior Developer Edge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ZuperiorDeveloperEdge "$APP/Contents/MacOS/ZuperiorDeveloperEdge"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/icon.png "$APP/Contents/Resources/icon.png"
cp assets/logo.png "$APP/Contents/Resources/logo.png"
cp scripts/git_fetch_all.sh "$APP/Contents/Resources/git_fetch_all.sh"
chmod +x "$APP/Contents/Resources/git_fetch_all.sh"
cp scripts/update.sh "$APP/Contents/Resources/update.sh"
chmod +x "$APP/Contents/Resources/update.sh"
cp assets/celebrations.json "$APP/Contents/Resources/celebrations.json"
cp developer-edge.example.json "$APP/Contents/Resources/developer-edge.example.json"
[ -f assets/mascot.png ] && cp assets/mascot.png "$APP/Contents/Resources/mascot.png" || true
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Built $PWD/$APP"

if [[ "${1:-}" == "--install" ]]; then
    DEST="/Applications/Zuperior Developer Edge.app"
    pkill -9 -f "ZuperiorDeveloperEdge" 2>/dev/null || true
    sleep 0.5
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    # Store repo path so the app can find update.sh on any machine
    defaults write com.zuperior.developeredge repoPath "$PWD"
    open "$DEST"
    echo "Installed to $DEST and launched."
    echo "To start at login: System Settings > General > Login Items > + → /Applications/Zuperior Developer Edge.app"
else
    echo "Next: run with --install to copy to /Applications, or drag it there manually."
    echo "Add it under System Settings > General > Login Items to start at login."
fi
