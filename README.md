# Traffic Pro

[![CI](https://github.com/juanroman/traffic-pro/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/juanroman/traffic-pro/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: iOS 27.2+](https://img.shields.io/badge/platform-iOS%2027.2%2B-lightgrey.svg)](ios/README.md)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](ios/README.md)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-025e8c.svg)](.github/dependabot.yml)

A personal iPhone app that shows traffic-aware ETAs for your saved commutes. Home shows the
commute nearest to you with one chip per route; Details opens a map and a sheet to edit routes
and via points. It calls Google's Routes API directly, keeps commutes as JSON on the device,
and uses MapKit for place search. No server. English and Spanish (Mexico).

Not for sale; built for one person's daily drive.

## Requirements
- Xcode with the iOS 27.2 SDK
- SwiftLint (`brew install swiftlint`)
- A Google Routes API key (see below)

## Setup
1. `cp ios/Secrets.example.plist ios/TrafficPro/TrafficPro/Secrets.plist`
2. Put your key in `GOOGLE_ROUTES_API_KEY`. The file is git-ignored.
3. Open `ios/TrafficPro/TrafficPro.xcodeproj` and run the `TrafficPro` scheme.

Key restrictions and a live smoke test are in [`ios/README.md`](ios/README.md).

## Test
`ios/check.sh` — format, lint, package tests and app tests on a simulator. It must pass before
every commit.

CI (`.github/workflows/ci.yml`) runs on every PR: lint, package tests, and one job that builds,
runs the unit tests and a short UI smoke set (`SMOKE_TESTS` in `ios/check.sh`). The full UI suite
is slow on a CI runner: run it locally with `ios/check.sh` before merging UI changes, or on demand
from the Actions tab ("UI tests (full)"). It uses the `xcode-27` runner, the only image with the
iOS 27.2 SDK. Dependabot keeps the pinned action versions current.

## Layout
- `ios/TrafficPro/` — app target, unit tests, UI tests, string catalogs, assets
- `ios/TrafficProKit/` — Swift package: Domain, Mocks, Platform, Features
- `docs/decisions.md` — product decisions, Google terms, localization, pitfalls

## Localization
How to add strings (by hand, in the app target's catalog) is in the "Languages" section of
[`ios/README.md`](ios/README.md).

## TestFlight
`ios/upload-testflight.sh` archives and uploads. Run it only deliberately; each upload is a
new build.

## License
MIT, see [`LICENSE`](LICENSE), with the third-party exception below.

## Third-party notice
The Google Maps logo files (`ios/TrafficPro/TrafficPro/Assets.xcassets/GoogleMapsLogo.imageset`)
are © Google and are **not** covered by this repository's MIT license. They are included only to
show the attribution that Google's terms require wherever Routes data is shown. If you fork this
repo, follow [Google Maps Platform's attribution guidelines][attribution] for any use of them.

[attribution]: https://developers.google.com/maps/documentation/routes/policies
