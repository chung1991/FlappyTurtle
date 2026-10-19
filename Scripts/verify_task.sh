#!/bin/bash
# SWE-bench style verifier. Injects a task's hidden tests into a source tree,
# runs the whole suite on a simulator and grades FAIL_TO_PASS / PASS_TO_PASS.
#
#   Scripts/verify_task.sh moving-pipes                    # grade this tree
#   Scripts/verify_task.sh moving-pipes --tree /tmp/base   # grade another checkout (e.g. the base commit)
#   Scripts/verify_task.sh moving-pipes --record           # gold solution only: record reference screenshots
#   Scripts/verify_task.sh moving-pipes --fast             # unit tests only (skips UI verifiers), for quick iterations
#
# Task layout: Verification/<task>/{TASK.md, tests.json, hidden/unit/*.swift,
# hidden/ui/*.swift, baselines/}. "*existing*" in PASS_TO_PASS means every test
# that is not one of the task's hidden tests. Exit 0 = RESOLVED.
set -euo pipefail
source "$(dirname "$0")/env.sh"

TASK="${1:?usage: verify_task.sh <task> [--tree DIR]}"
shift
TREE="$ROOT"
RECORD=0
FAST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tree) TREE="$(cd "$2" && pwd)"; shift ;;
    --record) RECORD=1 ;;
    --fast) FAST=1 ;;
  esac
  shift
done

TASK_DIR="$ROOT/Verification/$TASK"
[ -f "$TASK_DIR/tests.json" ] || { echo "no task $TASK_DIR"; exit 2; }
INJECT_UNIT="$TREE/NativeFlappyTurtleTests/_Hidden_$TASK"
INJECT_UI="$TREE/NativeFlappyTurtleUITests/_Hidden_$TASK"
cleanup() { rm -rf "$INJECT_UNIT" "$INJECT_UI"; }
trap cleanup EXIT
cleanup
mkdir -p "$INJECT_UNIT" "$INJECT_UI"
cp "$TASK_DIR"/hidden/unit/*.swift "$INJECT_UNIT/" 2>/dev/null || true
cp "$TASK_DIR"/hidden/ui/*.swift "$INJECT_UI/" 2>/dev/null || true

UDID=$(sim_udid)
# Separate DerivedData per tree so base and solution builds never mix.
TREE_KEY=$(echo "$TREE" | shasum | cut -c1-8)
DD="$HOME/Library/Developer/Xcode/DerivedData/NativeFlappyTurtle-verify-$TREE_KEY"
RESULT="/tmp/nativeflappyturtle/verify-$TASK-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p /tmp/nativeflappyturtle
echo "Verifying '$TASK' on $TREE (sim $UDID)"

set +e
TEST_RUNNER_FT_HIDDEN_BASELINES="$TASK_DIR/baselines" TEST_RUNNER_FT_RECORD_HIDDEN=$RECORD \
xcodebuild test -project "$TREE/NativeFlappyTurtle.xcodeproj" -scheme "$SCHEME" \
  -destination "id=$UDID" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO $([ "$FAST" = 1 ] && echo "-only-testing:NativeFlappyTurtleTests") > "$RESULT.log" 2>&1
set -e

python3 - "$RESULT" "$TASK_DIR/tests.json" "$TASK_DIR/hidden" "$FAST" <<'PY'
import json, subprocess, sys, os, re, glob
result, spec_path, hidden_dir, fast = sys.argv[1:5]
spec = json.load(open(spec_path))
outcomes = {}
if os.path.exists(result):
    raw = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", result],
                         capture_output=True, text=True).stdout
    def walk(node, cls=None):
        kind = node.get("nodeType")
        if kind == "Test Suite":
            cls = node.get("name")
        if kind == "Test Case":
            outcomes[f"{cls}/{node.get('name')}"] = node.get("result")
        for child in node.get("children", []):
            walk(child, cls)
    for node in json.loads(raw or "{}").get("testNodes", []):
        walk(node)

hidden_classes = set()
for path in glob.glob(os.path.join(hidden_dir, "*", "*.swift")):
    hidden_classes |= set(re.findall(r"final class (\w+): XCTestCase", open(path).read()))

ui_classes = set()
for path in glob.glob(os.path.join(hidden_dir, "ui", "*.swift")):
    ui_classes |= set(re.findall(r"final class (\w+): XCTestCase", open(path).read()))
if fast == "1":
    print("FAST mode: UI verifiers and UI tests skipped")
    for key in ("FAIL_TO_PASS", "PASS_TO_PASS"):
        spec[key] = [n for n in spec[key] if n.split("/")[0] not in ui_classes]

def grade(names):
    ok, bad = [], []
    for name in names:
        if name == "*existing*":
            existing = [n for n in outcomes if n.split("/")[0] not in hidden_classes]
            if not existing:
                bad.append("*existing* (no tests ran - build failed?)")
            for n in existing:
                (ok if outcomes[n] == "Passed" else bad).append(n)
            continue
        (ok if outcomes.get(name) == "Passed" else bad).append(f"{name} [{outcomes.get(name, 'missing')}]" if outcomes.get(name) != "Passed" else name)
    return ok, bad

report = {}
for key in ("FAIL_TO_PASS", "PASS_TO_PASS"):
    ok, bad = grade(spec[key])
    report[key] = {"success": len(ok), "failure": bad}
resolved = not report["FAIL_TO_PASS"]["failure"] and not report["PASS_TO_PASS"]["failure"]
report["resolved"] = resolved
print(json.dumps(report, indent=2))
print("RESOLVED" if resolved else "NOT RESOLVED")
sys.exit(0 if resolved else 1)
PY
