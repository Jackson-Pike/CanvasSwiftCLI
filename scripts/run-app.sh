#!/bin/bash
# Build CanvasApp and launch it as a real .app bundle.
#
# WHY THIS EXISTS: `swift run CanvasApp` produces an executable with no Info.plist, so
# LaunchServices registers it as "BackgroundOnly" (= NSApplicationActivationPolicyProhibited).
# Status items are still permitted from that policy, so the menu bar icon and popover work —
# but a BackgroundOnly process cannot present a regular window. The `Window("Canvas", id: "main")`
# scene never appears, `openWindow(id:)` silently no-ops, and `NSApp.activate` does nothing.
#
# Wrapping the binary in a bundle applies App/Info.plist, whose LSUIElement=true maps to
# NSApplicationActivationPolicyAccessory — a menu-bar app that CAN show windows.
#
# Usage: scripts/run-app.sh [--release]

set -euo pipefail

CONFIG="debug"
[[ "${1:-}" == "--release" ]] && CONFIG="release"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --product CanvasApp

BIN="$(swift build -c "$CONFIG" --product CanvasApp --show-bin-path)/CanvasApp"
[[ -x "$BIN" ]] || { echo "error: binary not found at $BIN" >&2; exit 1; }

APP="$REPO_ROOT/.build/Canvas.app"
echo "==> Assembling $APP"

# Quit a previous instance so `open` launches the new build rather than activating the old one.
pkill -f "Canvas.app/Contents/MacOS/CanvasApp" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/CanvasApp"
cp "$REPO_ROOT/CanvasApp/App/Info.plist" "$APP/Contents/Info.plist"

# The checked-in plist is the source of truth for LSUIElement/bundle id; these two keys are
# required for a valid bundle but are normally supplied by Xcode at package time.
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string CanvasApp" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true

# Ad-hoc signature: keeps the Keychain ACL stable across rebuilds of the same path.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: ad-hoc codesign failed" >&2

echo "==> Launching (menu bar icon: graduation cap)"
open "$APP"
