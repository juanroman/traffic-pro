#!/usr/bin/env bash
# Archive and upload to App Store Connect (TestFlight).
# Why TestFlight and not Ad Hoc: on the owner's iPhone, Ad Hoc builds kept asking
# for Developer Mode however they were installed; TestFlight builds don't.
# The build number is a timestamp so every upload is unique without touching the repo.
# What was uploaded is recorded by a git tag `testflight/<version>-<build>` on the commit and an
# entry in CHANGELOG.md (see "Releases" in CLAUDE.md). The script tags locally and prints the
# entry; it never pushes.
set -euo pipefail
cd "$(dirname "$0")"

# Only a pushed commit on main is uploaded, so the tag always points at code the repo has.
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Upload from main (current branch: $(git branch --show-current))." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Tracked files have uncommitted changes; commit or stash them first." >&2
  exit 1
fi
git fetch --quiet origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "HEAD is not origin/main; pull or push first." >&2
  exit 1
fi
COMMIT="$(git rev-parse --short HEAD)"

VERSION="$(grep -h '"MARKETING_VERSION"' TrafficPro/TrafficPro.xcodeproj/project.xcproj \
  | sed -E 's/.*: "([^"]+)".*/\1/' | sort -u)"
if [[ "$(wc -l <<<"$VERSION")" -ne 1 || -z "$VERSION" ]]; then
  echo "MARKETING_VERSION is not the same in every target: ${VERSION//$'\n'/, }" >&2
  exit 1
fi

TEAM_ID="832TDP3BE8"
BUILD="$(date +%Y%m%d%H%M)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -project TrafficPro/TrafficPro.xcodeproj -scheme TrafficPro -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$WORK/TrafficPro.xcarchive" \
  -xcconfig arm64e.xcconfig \
  CURRENT_PROJECT_VERSION="$BUILD" -allowProvisioningUpdates archive -quiet
xcodebuild -exportArchive -archivePath "$WORK/TrafficPro.xcarchive" -exportPath "$WORK/export" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" -allowProvisioningUpdates
echo "Uploaded $VERSION ($BUILD) from $COMMIT"

TAG="testflight/$VERSION-$BUILD"
git tag -a "$TAG" -m "TestFlight $VERSION ($BUILD)" "$COMMIT"
cat <<EOF

Tagged $TAG (local). Push it when ready:  git push origin $TAG
Add this to CHANGELOG.md (move the Unreleased notes under it):

## $VERSION ($BUILD) - $(date +%Y-%m-%d)

Commit \`$COMMIT\`, tag \`$TAG\`.
EOF
