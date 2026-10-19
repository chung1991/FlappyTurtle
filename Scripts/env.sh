# Shared settings for the scripts in this folder. Source, don't run.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/NativeFlappyTurtle.xcodeproj"
SCHEME="NativeFlappyTurtle"
BUNDLE_ID="com.droidtapgames.nativeflappyturtle"
DERIVED="${DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/NativeFlappyTurtle-sim}"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/NativeFlappyTurtle.app"

# Simulator: $SIM_UDID, else the first booted device, else boot "iPhone 17".
sim_udid() {
  if [ -n "${SIM_UDID:-}" ]; then echo "$SIM_UDID"; return; fi
  local booted
  booted=$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1)
  if [ -n "$booted" ]; then echo "$booted"; return; fi
  local udid
  udid=$(xcrun simctl list devices available | grep -E "^\s+iPhone 17 \(" | grep -Eo '[0-9A-F-]{36}' | head -1)
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  echo "$udid"
}
