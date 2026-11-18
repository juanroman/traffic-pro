# Decisions, constraints and pitfalls

## Product / design
- Home is the hub: Home → Details (map + sheet) → route/schedule editors. The ⋯ menu has
  Add Commute…, and with 2+ commutes Manage Commutes…. No commutes list, no "Show ETAs" sheet.
- Home shows ONE commute: nearest origin within ~1 km; ties go to the most recently viewed; no
  permission or nothing nearby goes to the last viewed; a segmented selector overrides (a menu at
  5+); a "Near X" line explains the pick. Only the shown commute is fetched. User location stays
  on the device.
- ETA presentation: a tinted chip per route in the route's own map color, its name, "Fastest" in
  green, bold minutes. Big-numeral, arrival-time and bar designs were **rejected**. Keep the UI
  plain and system-native. Routes keep the commute's own order, never sorted.
- Refresh on every open/foreground/switch plus pull-to-refresh; no Refresh button; footer
  "Updated 12 seconds ago".
- Weekly schedules exist in the data model but the editor is hidden (the `-show-schedules` launch
  argument reveals it): they only fed an earlier server-side checker. Via points are not snapped to roads
  (accepted).
- Icon: **Timeline** (stacked ETA pills + a spine with stop dots), light/dark/tinted variants,
  default system blue accent.

## Apple Watch (companion, not a replacement)
- A quick look at the ETAs: read-only, no maps, no editing on the watch. Commutes are edited on the
  phone and synced to the watch (definitions only, never ETAs).
- The watch fetches ETAs itself from Google (`URLSession`). A GPS-only watch reaches the network
  through the paired phone or Wi-Fi; that is transparent to the code.
- **No complication or widget.** Decided by the owner: it would mean the system storing ETAs.
- Target `TrafficProWatch`, bundle ID `mx.juanroman.traffic-pro.watchkitapp` (kept on purpose), watchOS
  27.2. It bundles the same git-ignored `Secrets.plist` through a target-membership exception;
  never copy the file. The Google key's restrictions must allow the watch bundle ID.
- Shared code: `Domain`, `HomeCore` (UI-free Home models), `Platform`, `Mocks`. `Features` is
  iOS-only.
- The glance screen reuses `HomeModel` (same pick rule as the phone). Its chips, card and footer are
  watch-sized copies of the phone's, and `Color(hex:)` and `RelativeAgeSchedule` are copies too,
  because `Features` is iOS-only. Change one, check the other. The Google logo is the same image
  set, at the guide's smallest height (16 pt).
- With 2+ commutes the commute name is a button (chevron) that opens a list to pick from; swiping
  between pages was rejected because it clashes with scrolling and pull to refresh. Choosing one
  counts as "viewed", like on the phone.
- **Handoff to the iPhone is not built.** It needs `NSUserActivityTypes` in the phone's Info.plist
  (a generated plist can't hold that array through build settings, so a plist file would be added
  to the phone target), plus handling the activity in `RootView`; and a simulator can't test it.
  Do it only if wanted, and test on devices.
- The watch catalogs (`Localizable`, `InfoPlist`) hold only the strings the watch can show,
  including package strings (`String(localized:)` looks in the main bundle): when the watch shows a
  new package string, copy its entry from the phone catalog.
- `-mock-services` on the watch uses the sample data with the user at "Home", to see the screens in
  a simulator without Google calls: `xcrun simctl launch <watch> mx.juanroman.traffic-pro.watchkitapp
  -mock-services` (add `-AppleLanguages "(es-MX)"` for Spanish).
- On watchOS a bare `UserDefaults.init` reference resolves to a deprecated initializer; name
  `UserDefaults(suiteName:)` explicitly.

## Google terms (verified 2026-11-13)
- ETAs are held in memory only, never persisted (only place_id and lat/lng may be cached 30 days).
- Show the "Google Maps" attribution in the same container as the data. No speech features.
- Routes content next to a non-Google map is technically forbidden by SST §19.2, and
  `FileRouteLineCache` persists polylines. The owner knowingly left the MapKit map as is. Don't
  "fix" this unasked.
- Before making the repo public: run a secrets scan and check Google's attribution-asset terms.

## Localization
- es-MX is the only translation. Catalogs live in the **app target**, not the package, so
  `Text("…")` finds them.
- Xcode does not extract package strings: add keys **by hand** with the exact English text
  (`%@`, `%lld`).
- `Text(someString)` is NOT localized; use `String(localized:)` or `LocalizedStringKey`.
- Plurals are separate keys.
- Terminology: commute = "trayecto", route = "ruta", ETA = "tiempo", via point =
  "punto intermedio", informal "tú".
- Accessibility identifiers stay English.
- `es`/`es-419`/`es-US` devices show English (undecided). `LocalizationCatalogTests` guards the
  catalogs.

## Pitfalls learned the hard way
- Do **not** move the commute screen's alerts/sheets into a `ViewModifier`: the sheet `List`
  crashed when deleting the last route. Keep them inline. `CommuteMapScreen` is near SwiftLint's
  250-line type limit.
- After **any** refactor of that screen, run the UI tests (at least the delete-route ones with
  `-test-iterations 3 -run-tests-until-failure`), not just lint.
- Sheet content built once does not see later `@State` changes; read live state (environment or
  bindings).
- UI tests use `app.expandCommuteSheet()`, `app.openCommute(name)` and
  `chooseFromHomeMenu("home-add"|"home-manage")`. Known gap: no test for the empty-state button.
- UI tests launch with `-mock-services -no-animations` (`LaunchArguments.base`). Without
  `-no-animations`, a system menu or keyboard can leave an animation XCTest never sees finish, and
  every later action waits 60 s for idle. It never happened locally, but on the CI runner it
  stretched the UI tests from ~9 to 38+ minutes and killed tests by timeout.
- Flaky UI test: rerun it alone several times and fix the cause (alerts attached to a `Section`
  inside a `List` were unreliable).
- Reverting a hack with `git checkout <file>` also discards real uncommitted edits in that file.
- Deleting the app from the phone erases saved commutes (JSON in the app container). A different
  bundle ID is a different container.

## Distribution
- Bundle ID `mx.juanroman.traffic-pro` (tests: `.tests`, `.uitests`), team `832TDP3BE8`,
  automatic signing.
- TestFlight build number is a timestamp. Upload only with the owner's explicit OK.
