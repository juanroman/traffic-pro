#!/usr/bin/env bash
# "Is the iOS project green?"
#
#   ios/check.sh [all]   the full local gate: every stage below, with all UI tests
#   ios/check.sh lint    secrets are not tracked, security guards, swift-format, SwiftLint
#   ios/check.sh security  only the security guards (part of lint)
#   ios/check.sh package package tests (warnings are errors)
#   ios/check.sh build   app build-for-testing on a simulator
#   ios/check.sh unit    app unit tests (needs `build` first)
#   ios/check.sh device  unsigned arm64e device build, as TestFlight builds it (not run on CI)
#   ios/check.sh smoke   the few UI tests CI runs on every PR, retrying a failed test once
#                        (needs `build` first)
#   ios/check.sh ui [Class[/test] ...]
#                        all UI tests, or only the given ones (needs `build` first)
#
# CI runs lint, package, build, unit and smoke as separate steps so a failure says which stage
# broke. The full UI suite is slow on a CI runner, so it runs locally (`all` / `ui`) or on demand
# from the "UI tests (full)" workflow.
# Set RESULTS_DIR to keep an .xcresult bundle per xcodebuild stage (CI uploads them on failure).
set -euo pipefail
cd "$(dirname "$0")"

SIM_NAME="${SIM_NAME:-iPhone 18 Pro}"
SIM_OS="${SIM_OS:-27.2}" # several runtimes are installed; the name alone is ambiguous
SWIFT_DIRS=(TrafficProKit/Sources TrafficProKit/Tests TrafficPro/TrafficPro TrafficPro/TrafficProTests TrafficPro/TrafficProUITests TrafficPro/TrafficProWatch)
PROJECT=TrafficPro/TrafficPro.xcodeproj
SCHEME=TrafficPro
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}" # git-ignored; shared by build/unit/ui
DESTINATION="platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}"

# One path through each screen that matters, avoiding the gesture-heavy tests (menu, drag,
# pull-to-refresh, map) that are slow and flaky on a CI runner. Change the list here.
SMOKE_TESTS=(
  HomeUITests/testEachChipReadsAsOneThingWithMinutesAndExactlyOneIsFastest # Home shows the ETAs
  HomeUITests/testTheNumbersCarryTheirAgeAndGoogleSAttribution # Google attribution (terms)
  TrafficProUITests/testDrillIntoACommuteAndBack # Home -> Details -> back
  TrafficProUITests/testAddRenameRecolorAndDeleteARoute # editing, incl. deleting a route
  NewCommuteUITests/testCreatingACommuteOpensItReadyForItsFirstRoute # add a commute
  LocalizationUITests/testHomeSpeaksSpanish # es-MX
)

result_bundle_args() { # $1 = stage name
  if [[ -n "${RESULTS_DIR:-}" ]]; then
    mkdir -p "$RESULTS_DIR"
    rm -rf "${RESULTS_DIR:?}/$1.xcresult" # xcodebuild refuses to overwrite a bundle
    echo "-resultBundlePath" "$RESULTS_DIR/$1.xcresult"
  fi
}

# Guards that fail when a hardening decision is undone by accident (docs/xcode-security-settings.md)
# or a secret is committed. Part of `lint`, so CI runs it on every PR.
stage_security() {
  echo "--- security: Enhanced Security settings and entitlements ---"
  local project_file="$PROJECT/project.xcproj" entitlements=TrafficPro/TrafficPro/TrafficPro.entitlements
  local setting
  for setting in ENABLE_ENHANCED_SECURITY ENABLE_USER_SCRIPT_SANDBOXING; do
    grep -q "\"$setting\": \"YES\"" "$project_file" || {
      echo "$setting is not YES in $project_file" >&2
      exit 1
    }
  done
  local key
  for key in hardened-process hardened-process.hardened-heap hardened-process.dyld-ro \
    hardened-process.checked-allocations; do
    plutil -convert json -o - "$entitlements" | grep -q "\"com.apple.security.$key\":true" || {
      echo "Entitlement com.apple.security.$key is not true in $entitlements" >&2
      exit 1
    }
  done
  # Any other entitlement widens what the app may do, so adding one has to be a decision made here.
  local unexpected
  unexpected="$(plutil -convert json -o - "$entitlements" | tr ',' '\n' | grep -o '"com\.apple\.[^"]*"' \
    | grep -v '"com\.apple\.security\.hardened-process' || true)"
  if [[ -n "$unexpected" ]]; then
    echo "Unexpected entitlement(s) in $entitlements (allow them in check.sh if intended):" >&2
    echo "$unexpected" >&2
    exit 1
  fi

  echo "--- security: App Transport Security is not weakened ---"
  # Every request must use HTTPS: no arbitrary-loads switch and no per-domain exceptions.
  if hits="$(git ls-files -z .. | xargs -0 grep -I -l 'NSAllowsArbitraryLoads\|NSExceptionAllowsInsecureHTTPLoads\|NSExceptionDomains' 2>/dev/null \
    | grep -Ev '(^|/)check\.sh$|\.md$')" && [[ -n "$hits" ]]; then
    echo "App Transport Security is weakened in:" >&2
    echo "$hits" >&2
    exit 1
  fi

  echo "--- security: gitleaks (all history, matches redacted) ---"
  if ! command -v gitleaks >/dev/null; then
    echo "gitleaks not installed (brew install gitleaks)" >&2
    exit 1
  fi
  gitleaks git --no-banner --redact ..
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

  stage_security

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

# The watch target lists Secrets.plist explicitly (the phone app's folder is synced, so a missing
# file never mattered), so a build needs the file to exist. Without a real key, as on CI or a fresh
# clone, the template with its placeholder is enough: the app then reports "add your key" at
# runtime and the tests use mocks. A real file is never touched.
ensure_secrets_file() {
  local target=TrafficPro/TrafficPro/Secrets.plist
  if [[ ! -f "$target" ]]; then
    echo "--- no Secrets.plist: using the placeholder template (no real key) ---"
    cp Secrets.example.plist "$target"
  fi
}

stage_build() {
  ensure_secrets_file
  echo "--- app build-for-testing (xcodebuild) ---"
  # shellcheck disable=SC2046
  xcodebuild build-for-testing -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
    $(result_bundle_args build) -quiet
}

# Production builds are arm64e (arm64e.xcconfig), but simulator builds never are, so nothing above
# would notice a break. This compiles the apps for a real device without signing and checks that
# both binaries really got an arm64e slice. Not run on CI (a device build is slow there).
stage_device() {
  ensure_secrets_file
  echo "--- device build, arm64e (xcodebuild, no signing) ---"
  local derived="$DERIVED_DATA-device"
  # shellcheck disable=SC2046
  xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$derived" \
    -xcconfig arm64e.xcconfig CODE_SIGNING_ALLOWED=NO \
    $(result_bundle_args device) -quiet
  local app="$derived/Build/Products/Release-iphoneos/TrafficPro.app"
  for binary in "$app/TrafficPro" "$app/Watch/TrafficProWatch.app/TrafficProWatch"; do
    if ! lipo -archs "$binary" | grep -qw arm64e; then
      echo "no arm64e slice in $binary: $(lipo -archs "$binary")" >&2
      exit 1
    fi
  done
}

# $1 = result bundle name; remaining args = -only-testing:... selectors
run_tests() {
  local name="$1"
  shift
  local xctestrun
  xctestrun="$(ls "$DERIVED_DATA"/Build/Products/*.xctestrun 2>/dev/null | head -1)"
  if [[ -z "$xctestrun" ]]; then
    echo "no .xctestrun under $DERIVED_DATA/Build/Products; run \`ios/check.sh build\` first" >&2
    exit 1
  fi
  # No -quiet: the per-test lines show progress and which test is slow or stuck. A test that
  # hangs is failed by the timeouts instead of stalling the whole job.
  echo "--- app $name tests (xcodebuild) ---"
  # shellcheck disable=SC2046
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "$DESTINATION" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    -maximum-test-execution-time-allowance 300 \
    "$@" $(result_bundle_args "$name") 2>&1 \
    | grep --line-buffered -v 'IDELaunchParametersSnapshot\|IDETestOperationsObserverDebug'
}

stage_unit() {
  run_tests unit -only-testing:TrafficProTests
}

stage_ui() { # optional args: Class or Class/test
  local only=()
  if (($# > 0)); then
    for test in "$@"; do only+=("-only-testing:TrafficProUITests/$test"); done
  else
    only=("-only-testing:TrafficProUITests")
  fi
  run_tests ui "${only[@]}"
}

stage_smoke() {
  local only=()
  for test in "${SMOKE_TESTS[@]}"; do only+=("-only-testing:TrafficProUITests/${test%% *}"); done
  # A cold simulator launch on a CI runner occasionally times out the first UI test. Retry a
  # failed test once (only that test); a retry that passes is still recorded in the .xcresult.
  run_tests smoke "${only[@]}" -retry-tests-on-failure -test-iterations 2
}

case "${1:-all}" in
  lint) stage_lint ;;
  security) stage_security ;;
  package) stage_package ;;
  build) stage_build ;;
  unit) stage_unit ;;
  device) stage_device ;;
  smoke) stage_smoke ;;
  ui)
    shift
    stage_ui "$@"
    ;;
  all)
    stage_lint
    stage_package
    stage_build
    stage_unit
    stage_ui
    stage_device
    echo "iOS checks passed."
    ;;
  *)
    echo "usage: ios/check.sh [all|lint|security|package|build|unit|smoke|ui|device]" >&2
    exit 2
    ;;
esac
