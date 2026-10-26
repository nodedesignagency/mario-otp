#!/usr/bin/env bash
# Builds Mario OTP and launches it in the iOS Simulator.
#
#   ./scripts/run.sh                     # booted simulator, else the newest iPhone
#   ./scripts/run.sh "iPhone 16 Pro"     # a specific simulator by name
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.nodedesign.MarioOTP"
DERIVED="build/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/MarioOTP.app"
UUID_RE='[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'

if ! xcode-select -p 2>/dev/null | grep -q "\.app/"; then
  echo "✋ xcodebuild is pointing at the Command Line Tools, not Xcode. Fix with:"
  echo "   sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi

if [[ $# -gt 0 ]]; then
  UDID=$(xcrun simctl list devices available | grep -F "    $1 (" | tail -1 | grep -oE "$UUID_RE" || true)
  [[ -n "$UDID" ]] || { echo "✋ No available simulator named \"$1\". Try: xcrun simctl list devices available"; exit 1; }
else
  UDID=$(xcrun simctl list devices booted | grep -E '^ +iPhone' | head -1 | grep -oE "$UUID_RE" || true)
  if [[ -z "$UDID" ]]; then
    AVAILABLE=$(xcrun simctl list devices available)
    UDID=$(echo "$AVAILABLE" | grep -E '^ +iPhone [0-9]+ Pro \(' | tail -1 | grep -oE "$UUID_RE" || true)
    [[ -n "$UDID" ]] || UDID=$(echo "$AVAILABLE" | grep -E '^ +iPhone' | tail -1 | grep -oE "$UUID_RE" || true)
  fi
  [[ -n "$UDID" ]] || { echo "✋ No iPhone simulators found. Add one in Xcode → Settings → Components."; exit 1; }
fi

NAME=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/^ +//; s/ \(.*//' | head -1)
echo "📱 Simulator: $NAME"

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

echo "🔨 Building…"
xcodebuild \
  -project MarioOTP.xcodeproj \
  -scheme MarioOTP \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -quiet \
  build

echo "🍄 Launching…"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
echo "✅ Running on $NAME. Demo code: 1985"
