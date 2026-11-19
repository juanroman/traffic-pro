# Xcode Security Settings

Security build settings decisions for TrafficPro. Last audited 2026-11-18.

## Enabled settings

- `ENABLE_ENHANCED_SECURITY` (project level, so every target inherits it): stack zero-init and the other compiler-driven protections. Pointer authentication is the exception, see "Disabled settings".
- `TrafficPro` entitlements (`TrafficPro/TrafficPro.entitlements`):
  - `com.apple.security.hardened-process` with `enhanced-security-version-string` = `2`
  - `com.apple.security.hardened-process.hardened-heap`
  - `com.apple.security.hardened-process.dyld-ro`
  - `com.apple.security.hardened-process.platform-restrictions-string` = `2`
  - `com.apple.security.hardened-process.checked-allocations` (hardware memory tagging) with `soft-mode`, so tag faults are reported without terminating the app. Revisit and turn soft mode off once no simulated crash reports remain.

## Disabled settings

- `ENABLE_POINTER_AUTHENTICATION` = `NO` on `TrafficPro` and `TrafficProWatch`: with it on, the app is built as `arm64e`, but the local `TrafficProKit` package is built as plain `arm64`, so the Release archive fails with "Module file ... is incompatible with this Swift compiler: built for incompatible target". Found 2026-11-18 with an archive-only build (`xcodebuild archive`, generic iOS device); `main` archives fine and the simulator-based `ios/check.sh` cannot see it, because simulator builds never use `arm64e`. Revisit when the package can be built for `arm64e` too.

## Deferred

Settings considered but not yet enabled. Revisit them later.

- Checked pointer arithmetic (`ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` and the `enforce-checked-pointer-arithmetic-overflow` entitlement): it needs the `arm64e.x1` slice, which needs pointer authentication, which is disabled above. It also has no soft mode: a latent pointer-arithmetic bug terminates the app on A20 Pro or later hardware, so test on capable hardware first.

- Enhanced Security entitlements on `TrafficProWatch`: the Apple references disagree on whether watchOS supports them (the Enhanced Security reference lists iOS, macOS, visionOS and DriverKit; the memory tagging and checked pointer arithmetic references mention watchOS). The project-level `ENABLE_ENHANCED_SECURITY` still cascades to the watch target. Revisit once the support question is settled.
- Additional diagnostic settings (extra opt-in warnings and checkers): not requested in this audit.

## Not applicable

- The C, C++ and Objective-C warning, static analyzer and clang-tidy settings, plus `ENABLE_C_BOUNDS_SAFETY` and `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`: the project is pure Swift.
- `TrafficProTests` and `TrafficProUITests`: test bundles are outside the scope of Enhanced Security.
