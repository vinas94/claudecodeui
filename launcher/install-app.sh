#!/bin/bash
# Build the launcher and install it as an .app. Usage: install-app.sh <app path> <config path> <port>
# Paths go into Info.plist, so moving the repo only needs a re-run, not a rebuild.
set -euo pipefail

APP="$1"
CONFIG="$2"
PORT="$3"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"

swift build -c release --package-path "$HERE"
BIN="$(swift build -c release --package-path "$HERE" --show-bin-path)/cloudcli-launcher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CloudCLI"
sed -e "s|@CC_PROJECT@|$PROJECT|" -e "s|@CC_CONFIG@|$CONFIG|" -e "s|@CC_PORT@|$PORT|" \
  "$HERE/Info.plist" > "$APP/Contents/Info.plist"

# .icns from the project's own 512px logo
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for s in 16 32 128 256; do
  sips -z "$s" "$s" "$PROJECT/public/logo-512.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z "$((s * 2))" "$((s * 2))" "$PROJECT/public/logo-512.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
cp "$PROJECT/public/logo-512.png" "$SET/icon_512x512.png"
iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$SET")"

codesign --force --sign - "$APP" 2>/dev/null
touch "$APP"   # nudge Launch Services to reindex
echo "installed $APP"
