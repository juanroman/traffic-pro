# Traffic Pro

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
MIT, see [`LICENSE`](LICENSE).
