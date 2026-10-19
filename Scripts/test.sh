#!/bin/bash
# Run tests on a simulator.
#   Scripts/test.sh            # unit + UI (snapshots + flows)
#   Scripts/test.sh unit       # model/physics/layout tests only (~1s once built)
#   Scripts/test.sh ui         # UI tests only
#   Scripts/test.sh snapshots  # screenshot tests only
#   Scripts/test.sh snapshots --record   # re-record baselines after an intended visual change
# SIM_UDID=<udid> picks the simulator (baselines are per screen size).
set -euo pipefail
source "$(dirname "$0")/env.sh"

SUITE="${1:-all}"
RECORD=0
for arg in "$@"; do [ "$arg" = "--record" ] && RECORD=1; done

ONLY=()
case "$SUITE" in
  unit) ONLY=(-only-testing:NativeFlappyTurtleTests) ;;
  ui) ONLY=(-only-testing:NativeFlappyTurtleUITests) ;;
  snapshots) ONLY=(-only-testing:NativeFlappyTurtleUITests/SceneSnapshotTests) ;;
  flows) ONLY=(-only-testing:NativeFlappyTurtleUITests/GameplayFlowTests) ;;
  all|--record) ;;
  *) echo "unknown suite: $SUITE (unit|ui|snapshots|flows|all)"; exit 2 ;;
esac

UDID=$(sim_udid)
RESULT="/tmp/nativeflappyturtle/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p /tmp/nativeflappyturtle
rm -rf "$ROOT/Snapshots/Failures"
echo "Testing on $UDID ($SUITE, record=$RECORD) -> $RESULT"

set +e
TEST_RUNNER_FT_RECORD_SNAPSHOTS=$RECORD xcodebuild test -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO ${ONLY[@]+"${ONLY[@]}"} 2>&1 \
  | grep -E "error:|Test Case .*(passed|failed)|Executed [0-9]+ tests|\*\* TEST" | grep -v "Xcode3Core"
STATUS=${PIPESTATUS[0]}
set -e

if [ -d "$ROOT/Snapshots/Failures" ]; then
  echo "Snapshot diffs (actual + red diff): $ROOT/Snapshots/Failures"
fi
exit "$STATUS"
