#!/usr/bin/env bash
# "Is the iOS project green?"
#
#   ios/check.sh [all]   everything below, in order (the local gate)
#   ios/check.sh lint    secrets are not tracked, swift-format, SwiftLint
#   ios/check.sh package package tests (warnings are errors)
#   ios/check.sh build   app build-for-testing on a simulator
#   ios/check.sh unit    app unit tests (needs `build` first)
#   ios/check.sh ui      app UI tests (needs `build` first)
#
# CI runs the stages as separate steps so a failure says which stage broke.
# Set RESULTS_DIR to keep an .xcresult bundle per xcodebuild stage (CI uploads them on failure).
set -euo pipefail
cd "$(dirname "$0")"

SIM_NAME="${SIM_NAME:-iPhone 18 Pro}"
SIM_OS="${SIM_OS:-27.2}" # several runtimes are installed; the name alone is ambiguous
SWIFT_DIRS=(TrafficProKit/Sources TrafficProKit/Tests TrafficPro/TrafficPro TrafficPro/TrafficProTests TrafficPro/TrafficProUITests)
PROJECT=TrafficPro/TrafficPro.xcodeproj
SCHEME=TrafficPro
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}" # git-ignored; shared by build/unit/ui
DESTINATION="platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}"

result_bundle_args() { # $1 = stage name
  if [[ -n "${RESULTS_DIR:-}" ]]; then
    mkdir -p "$RESULTS_DIR"
    rm -rf "${RESULTS_DIR:?}/$1.xcresult" # xcodebuild refuses to overwrite a bundle
    echo "-resultBundlePath" "$RESULTS_DIR/$1.xcresult"
  fi
}

stage_lint() {
  echo "--- secrets are not tracked ---"
  if git ls-files --error-unmatch TrafficPro/TrafficPro/Secrets.plist >/dev/null 2>&1; then
    echo "TrafficPro/TrafficPro/Secrets.plist is tracked by git; it holds the API key" >&2
    exit 1
  fi
  git check-ignore -q TrafficPro/TrafficPro/Secrets.plist || {
    echo "Secrets.plist is not git-ignored" >&2
    exit 1
  }
  # A Google API key has this shape; the file names are printed, never the match itself.
  if hits="$(git ls-files -z .. | xargs -0 grep -I -l 'AIza[0-9A-Za-z_-]\{35\}' 2>/dev/null)" \
    && [[ -n "$hits" ]]; then
    echo "A Google API key pattern is in tracked file(s):" >&2
    echo "$hits" >&2
    exit 1
  fi

  echo "--- swift-format (lint, strict) ---"
  xcrun swift-format lint --strict --recursive "${SWIFT_DIRS[@]}"

  echo "--- swiftlint (strict) ---"
  if ! command -v swiftlint >/dev/null; then
    echo "swiftlint not installed (brew install swiftlint)" >&2
    exit 1
  fi
  swiftlint lint --strict --quiet
}

stage_package() {
  echo "--- package tests (warnings are errors) ---"
  (cd TrafficProKit && swift test)
}

stage_build() {
  echo "--- app build-for-testing (xcodebuild) ---"
  # shellcheck disable=SC2046
  xcodebuild build-for-testing -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
    $(result_bundle_args build) -quiet
}

stage_tests() { # $1 = unit | ui
  local target
  case "$1" in
    unit) target=TrafficProTests ;;
    ui) target=TrafficProUITests ;;
  esac
  # No -quiet here: the per-test lines are how you see progress (and which test is slow or stuck).
  # A test that hangs is failed by the timeouts below instead of stalling the whole job.
  echo "--- app $1 tests (xcodebuild) ---"
  # shellcheck disable=SC2046
  xcodebuild test-without-building -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    -maximum-test-execution-time-allowance 300 \
    -only-testing:"$target" $(result_bundle_args "$1") 2>&1 \
    | grep --line-buffered -v 'IDELaunchParametersSnapshot\|IDETestOperationsObserverDebug'
}

case "${1:-all}" in
  lint) stage_lint ;;
  package) stage_package ;;
  build) stage_build ;;
  unit) stage_tests unit ;;
  ui) stage_tests ui ;;
  all)
    stage_lint
    stage_package
    stage_build
    stage_tests unit
    stage_tests ui
    echo "iOS checks passed."
    ;;
  *)
    echo "usage: ios/check.sh [all|lint|package|build|unit|ui]" >&2
    exit 2
    ;;
esac
