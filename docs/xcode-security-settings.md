# Xcode Security Settings

Security build settings decisions for TrafficPro. Last audited 2026-11-18.

## Enabled settings

- `ENABLE_ENHANCED_SECURITY` (project level, so every target inherits it): turns on pointer authentication (`arm64e`), stack zero-init and the other compiler-driven protections.
- `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` on `TrafficPro`: builds the `arm64e.x1` slice.
- `TrafficPro` entitlements (`TrafficPro/TrafficPro.entitlements`):
  - `com.apple.security.hardened-process` with `enhanced-security-version-string` = `2`
  - `com.apple.security.hardened-process.hardened-heap`
  - `com.apple.security.hardened-process.dyld-ro`
  - `com.apple.security.hardened-process.platform-restrictions-string` = `2`
  - `com.apple.security.hardened-process.checked-allocations` (hardware memory tagging) with `soft-mode`, so tag faults are reported without terminating the app. Revisit and turn soft mode off once no simulated crash reports remain.
  - `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow`: has no soft mode. A latent pointer-arithmetic bug terminates the app on A20 Pro or later hardware. The app is pure Swift, so the risk is low, but test on capable hardware before shipping.

## Disabled settings

None.

## Deferred

Settings considered but not yet enabled. Revisit them later.

- Enhanced Security entitlements on `TrafficProWatch`: the Apple references disagree on whether watchOS supports them (the Enhanced Security reference lists iOS, macOS, visionOS and DriverKit; the memory tagging and checked pointer arithmetic references mention watchOS). The project-level `ENABLE_ENHANCED_SECURITY` still cascades to the watch target. Revisit once the support question is settled.
- Additional diagnostic settings (extra opt-in warnings and checkers): not requested in this audit.

## Not applicable

- The C, C++ and Objective-C warning, static analyzer and clang-tidy settings, plus `ENABLE_C_BOUNDS_SAFETY` and `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`: the project is pure Swift.
- `TrafficProTests` and `TrafficProUITests`: test bundles are outside the scope of Enhanced Security.
