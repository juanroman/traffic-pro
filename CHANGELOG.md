# Changelog

Every build uploaded to TestFlight, newest first. Merged work that has not been uploaded yet
is listed under Unreleased. Format loosely follows [Keep a Changelog](https://keepachangelog.com).

Each entry is `version (build)`: the version is `MARKETING_VERSION`, the build is the timestamp
`ios/upload-testflight.sh` makes at upload time. The commit and the git tag
`testflight/<version>-<build>` say exactly which code was uploaded. How to add an entry is in
[`CLAUDE.md`](CLAUDE.md#releases).

## [Unreleased]

### Changed
- Code scanning (CodeQL) now scans the Swift code with Xcode 27.2 through its own workflow, because GitHub's default setup used an older Swift and its build failed.

## 1.0 (202611210018) - 2026-11-21

Commit `3c59b2a`, tag `testflight/1.0-202611210018`.

### Changed
- Choosing a place for a commute no longer shows fixed Home and Work shortcuts. The picker lists
  the places from your other commutes under "Recent", so you can reuse any place.
- Long-press a place under "Recent" and choose Rename to give it a name like "Home". It changes
  in every commute that uses that place.
- The old Home and Work shortcut settings are gone. Places you picked for a commute are kept; one
  you only saved as a shortcut and never used in a commute no longer shows up.

## 1.0 (202611201730) - 2026-11-20

Commit `8cea687`, tag `testflight/1.0-202611201730`.

### Changed
- The apps are built as arm64e, so the iPhone and watch apps get pointer authentication.
  Simulator builds, Xcode runs and CI stay arm64. `ios/check.sh device` checks the arm64e build
  and `ios/upload-testflight.sh` tags every upload (PR #14, #15). Not yet tried on a real device
  at the time of the upload.

## 1.0 (202611200924) - 2026-11-20

Commit `014ae07`, tag `testflight/1.0-202611200924`. First entry in this file: it summarizes the
app up to this build; earlier TestFlight builds were not recorded.

### Added
- Home shows the commute nearest to you with one chip per route and the live traffic ETA.
- Details with a map and a sheet to edit routes and via points; add, rename, recolor, reorder
  and delete commutes and routes; search for places like Calendar's Location field, with Home
  and other shortcuts.
- Apple Watch app: shows the live ETAs and switches between commutes, with the commutes synced
  from the phone.
- English and Spanish (Mexico).

### Changed
- iPhone only (the iPad layout was dropped).
- Enhanced Security is on for the iPhone app: hardened process and heap, read-only dyld,
  platform restrictions and hardware memory tagging in soft mode. Checked on an iPhone 17 Pro
  with no crash reports.
- SwiftUI cleanups on Home, the routes list and the map views.

### Fixed
- The place picker's "couldn't find that place" alert can be dismissed.
- The watch app has its icon, and the location purpose string warning is gone.
