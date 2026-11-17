#!/usr/bin/env bash
# "Is the iOS project green?"
#
#   ios/check.sh [all]   everything below, in order (the local gate)
#   ios/check.sh lint    secrets are not tracked, swift-format, SwiftLint
#   ios/check.sh package package tests (warnings are errors)
#   ios/check.sh build   app build-for-testing on a simulator
#   ios/check.sh unit    app unit tests (needs `build` first)
#   ios/check.sh boot-sim / wait-sim
#                        start booting the simulator in the background / wait until it is ready
#                        (CI boots it while the build artifact downloads)
#   ios/check.sh ui [Class ...]
#                        app UI tests (needs `build` first); optionally only the given
#                        UI test classes, which is how CI shards them across jobs
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

simulator_udid() { # the name alone is ambiguous across runtimes, so look it up by OS
  xcrun simctl list devices available "iOS ${SIM_OS}" | grep "${SIM_NAME} (" \
    | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1
}

stage_boot_sim() {
  local udid
  udid="$(simulator_udid)"
  [[ -n "$udid" ]] || { echo "no ${SIM_NAME} simulator for iOS ${SIM_OS}" >&2; exit 1; }
  echo "--- booting ${SIM_NAME} (iOS ${SIM_OS}) ---"
  xcrun simctl boot "$udid" 2>&1 || true # already booted is fine
}

stage_wait_sim() {
  echo "--- waiting for the simulator ---"
  xcrun simctl bootstatus "$(simulator_udid)" -b
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

stage_tests() { # $1 = unit | ui; remaining args = test classes (ui only)
  local kind="$1" target only=()
  shift
  case "$kind" in
    unit) target=TrafficProTests ;;
    ui) target=TrafficProUITests ;;
  esac
  if (($# > 0)); then
    for class in "$@"; do only+=("-only-testing:$target/$class"); done
  else
    only=("-only-testing:$target")
  fi
  # Run from the .xctestrun that `build` produced, so CI shards need only the build products.
  local xctestrun
  xctestrun="$(ls "$DERIVED_DATA"/Build/Products/*.xctestrun 2>/dev/null | head -1)"
  if [[ -z "$xctestrun" ]]; then
    echo "no .xctestrun under $DERIVED_DATA/Build/Products; run \`ios/check.sh build\` first" >&2
    exit 1
  fi
  # No -quiet here: the per-test lines are how you see progress (and which test is slow or stuck).
  # A test that hangs is failed by the timeouts below instead of stalling the whole job.
  echo "--- app $kind tests (xcodebuild) ---"
  # shellcheck disable=SC2046
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "$DESTINATION" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    -maximum-test-execution-time-allowance 300 \
    "${only[@]}" $(result_bundle_args "$kind") 2>&1 \
    | grep --line-buffered -v 'IDELaunchParametersSnapshot\|IDETestOperationsObserverDebug'
}

case "${1:-all}" in
  lint) stage_lint ;;
  boot-sim) stage_boot_sim ;;
  wait-sim) stage_wait_sim ;;
  package) stage_package ;;
  build) stage_build ;;
  unit) stage_tests unit ;;
  ui)
    shift
    stage_tests ui "$@"
    ;;
  all)
    stage_lint
    stage_package
    stage_build
    stage_tests unit
    stage_tests ui
    echo "iOS checks passed."
    ;;
  *)
    echo "usage: ios/check.sh [all|lint|package|build|unit|ui|boot-sim|wait-sim]" >&2
    exit 2
    ;;
esac
