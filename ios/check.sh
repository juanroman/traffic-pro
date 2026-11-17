#!/usr/bin/env bash
# "Is the iOS project green?"
# Order: format -> lint -> package tests -> app build+tests on a simulator.
set -euo pipefail
cd "$(dirname "$0")"

SIM_NAME="${SIM_NAME:-iPhone 18 Pro}"
SIM_OS="${SIM_OS:-27.2}" # several runtimes are installed; the name alone is ambiguous
SWIFT_DIRS=(TrafficProKit/Sources TrafficProKit/Tests TrafficPro/TrafficPro TrafficPro/TrafficProTests TrafficPro/TrafficProUITests)

echo "--- secrets are not tracked ---"
if git ls-files --error-unmatch TrafficPro/TrafficPro/Secrets.plist >/dev/null 2>&1; then
  echo "TrafficPro/TrafficPro/Secrets.plist is tracked by git; it holds the API key" >&2
  exit 1
fi
git check-ignore -q TrafficPro/TrafficPro/Secrets.plist || {
  echo "Secrets.plist is not git-ignored" >&2
  exit 1
}

echo "--- swift-format (lint, strict) ---"
xcrun swift-format lint --strict --recursive "${SWIFT_DIRS[@]}"

echo "--- swiftlint (strict) ---"
if ! command -v swiftlint >/dev/null; then
  echo "swiftlint not installed (brew install swiftlint)" >&2
  exit 1
fi
swiftlint lint --strict --quiet

echo "--- package tests (warnings are errors) ---"
(cd TrafficProKit && swift test)

echo "--- app build + tests (xcodebuild) ---"
xcodebuild test -project TrafficPro/TrafficPro.xcodeproj -scheme TrafficPro \
  -destination "platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}" -quiet
echo "iOS checks passed."
