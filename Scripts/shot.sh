#!/bin/bash
# Jump straight to a scene on the simulator and screenshot it (landscape PNG).
#   Scripts/shot.sh gameover -ft-score 12 -ft-highscore 30
#   Scripts/shot.sh playing -ft-advance 8
#   Scripts/shot.sh menu --live            # don't freeze; watch it run
#   Scripts/shot.sh paused --compare       # also diff against the recorded baseline
# Scenes: menu ready playing paused gameover. Always muted, seeded (7) and on
# an in-memory high score. Output: /tmp/nativeflappyturtle/<scene>.png
set -euo pipefail
source "$(dirname "$0")/env.sh"

SCENE="${1:?usage: shot.sh <scene> [-ft-... args] [--live] [--compare] [--build]}"
shift
EXTRA=() ; FREEZE=(-ft-freeze) ; COMPARE=0 ; BUILD=0
for arg in "$@"; do
  case "$arg" in
    --live) FREEZE=() ;;
    --compare) COMPARE=1 ;;
    --build) BUILD=1 ;;
    *) EXTRA+=("$arg") ;;
  esac
done

if [ "$BUILD" = 1 ] || [ ! -d "$APP" ]; then "$(dirname "$0")/build.sh" >/dev/null; fi
UDID=$(sim_udid)
OUT_DIR=/tmp/nativeflappyturtle
mkdir -p "$OUT_DIR"
RAW="$OUT_DIR/$SCENE-raw.png"
OUT="$OUT_DIR/$SCENE.png"

xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" -ft-scene "$SCENE" -ft-seed 7 -ft-mute -ft-isolated \
  ${FREEZE[@]+"${FREEZE[@]}"} ${EXTRA[@]+"${EXTRA[@]}"} >/dev/null
sleep "${SHOT_DELAY:-2.5}"
xcrun simctl io "$UDID" screenshot "$RAW" >/dev/null 2>&1
sips -r 270 "$RAW" --out "$OUT" >/dev/null
echo "$OUT"

if [ "$COMPARE" = 1 ]; then
  SIZE=$(sips -g pixelWidth -g pixelHeight "$RAW" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')
  BASE="$ROOT/Snapshots/Baselines/$SIZE/$SCENE.png"
  [ -f "$BASE" ] || { echo "no baseline $BASE"; exit 1; }
  swift "$ROOT/Scripts/imgdiff.swift" "$RAW" "$BASE" --diff "$OUT_DIR/$SCENE-diff.png"
fi
