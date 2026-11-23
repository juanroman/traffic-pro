# Xcode Security Settings

Security build settings decisions for TrafficPro. Last audited 2026-11-18.

## Enabled settings

- `ENABLE_ENHANCED_SECURITY` (project level, so every target inherits it): stack zero-init and the other compiler-driven protections. Pointer authentication is the exception, see "Pointer authentication" below.
- `TrafficPro` entitlements (`TrafficPro/TrafficPro.entitlements`):
  - `com.apple.security.hardened-process` with `enhanced-security-version-string` = `2`
  - `com.apple.security.hardened-process.hardened-heap`
  - `com.apple.security.hardened-process.dyld-ro`
  - `com.apple.security.hardened-process.platform-restrictions-string` = `2`
  - `com.apple.security.hardened-process.checked-allocations` (hardware memory tagging) with `soft-mode`, so tag faults are reported without terminating the app. Revisit and turn soft mode off once no simulated crash reports remain.

## Guarded by `ios/check.sh security`

`ios/check.sh lint` (so CI too) runs `stage_security`, which fails when:

- `ENABLE_ENHANCED_SECURITY` or `ENABLE_USER_SCRIPT_SANDBOXING` is not `YES` in the project.
- Any of the four hardened-process entitlements above (`hardened-process`, `hardened-heap`, `dyld-ro`, `checked-allocations`) is not `true`.
- The entitlements file holds anything outside `com.apple.security.hardened-process*`. A new entitlement widens what the app may do, so allow it in `check.sh` on purpose when you add one.
- A tracked file mentions `NSAllowsArbitraryLoads`, `NSExceptionAllowsInsecureHTTPLoads` or `NSExceptionDomains` (App Transport Security weakened; every request must be HTTPS).
- `gitleaks` finds a secret anywhere in the git history (matches are redacted). It complements the Google-key pattern check in the lint stage. Install with `brew install gitleaks`.

Not guarded: the `arm64e` settings (`ios/check.sh device` covers them locally) and `soft-mode`.

## Pointer authentication (arm64e): production builds only

`ios/arm64e.xcconfig` turns on `ENABLE_POINTER_AUTHENTICATION` and sets `ARCHS` to `arm64 arm64e` for the `iphoneos` and `watchos` SDKs. `ios/upload-testflight.sh` passes it with `-xcconfig`, so TestFlight builds are arm64e. Xcode runs, `ios/check.sh` and CI use the project settings, where `ENABLE_POINTER_AUTHENTICATION` stays `NO` on `TrafficPro` and `TrafficProWatch`, so they stay arm64. Chosen so a plain Run or Archive in Xcode keeps working.

Why a command-line xcconfig and not a project setting: Xcode builds the local `TrafficProKit` package as its own project, so project and target settings, conditional ones included, never reach it. With pointer authentication on in the project, the apps become `arm64e` while the package stays `arm64`, and a Release archive fails with "Module file ... is incompatible with this Swift compiler: built for incompatible target" (found 2026-11-18 with an archive-only build; simulator builds never use `arm64e`, so the simulator gate cannot see it). Only command-line overrides (`-xcconfig`, `ARCHS=...`) apply to package targets. `ENABLE_POINTER_AUTHENTICATION` also does not set `ARCHS` for package targets, which is why the `ARCHS` line is needed. Verified 2026-11-20 with an archive: iPhone and watch binaries are `arm64 arm64e`, all hardened-process entitlements are signed, and a simulator build with the same xcconfig stays `arm64`.

`ios/check.sh device` builds the apps unsigned for a generic device with the xcconfig and fails if either binary has no `arm64e` slice. It is part of `ios/check.sh all` but not run on CI.

Not verified: that the arm64e build runs on a real iPhone and Apple Watch. Test it through TestFlight after the first upload. The research also found that Apple's documented workspace setting `iOSPackagesShouldBuildARM64e` covers iOS only (not watchOS), and a known Apple bug (FB19922007, FB22246971) matches the package symptom; watch Xcode 27.x release notes before dropping the xcconfig.

## Deferred

Settings considered but not yet enabled. Revisit them later.

- Checked pointer arithmetic (`ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` and the `enforce-checked-pointer-arithmetic-overflow` entitlement): it needs the `arm64e.x1` slice. `arm64e.x1` can now be added to the `ARCHS` lines in `ios/arm64e.xcconfig` (the package gets it the same way), but only after the arm64e build has run on a device. It also has no soft mode: a latent pointer-arithmetic bug terminates the app on A20 Pro or later hardware, so test on capable hardware first.

- Enhanced Security entitlements on `TrafficProWatch`: the Apple references disagree on whether watchOS supports them (the Enhanced Security reference lists iOS, macOS, visionOS and DriverKit; the memory tagging and checked pointer arithmetic references mention watchOS). The project-level `ENABLE_ENHANCED_SECURITY` still cascades to the watch target. Revisit once the support question is settled.
- Additional diagnostic settings (extra opt-in warnings and checkers): not requested in this audit.

## Not applicable

- The C, C++ and Objective-C warning, static analyzer and clang-tidy settings, plus `ENABLE_C_BOUNDS_SAFETY` and `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`: the project is pure Swift.
- `TrafficProTests` and `TrafficProUITests`: test bundles are outside the scope of Enhanced Security.
