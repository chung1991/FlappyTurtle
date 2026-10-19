#!/bin/bash
# Build the app for the simulator. Prints the .app path.
set -euo pipefail
source "$(dirname "$0")/env.sh"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build -quiet
echo "$APP"
