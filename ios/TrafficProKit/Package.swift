// swift-tools-version: 6.4
import PackageDescription

// Domain and Mocks are deliberately platform-neutral (no UIKit/MapKit) so a
// future watchOS target can link them unchanged (and HomeCore, the UI-free Home models).
// Features is iOS-only.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
  name: "TrafficProKit",
  platforms: [.iOS("27.2"), .watchOS(.v27), .macOS(.v27)],
  products: [
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Mocks", targets: ["Mocks"]),
    .library(name: "Platform", targets: ["Platform"]),
    .library(name: "HomeCore", targets: ["HomeCore"]),
    .library(name: "Features", targets: ["Features"]),
  ],
  targets: [
    .target(name: "Domain", swiftSettings: strict),
    .target(name: "Mocks", dependencies: ["Domain"], swiftSettings: strict),
    // System-framework implementations of the Domain protocols (MapKit, UserDefaults).
    .target(name: "Platform", dependencies: ["Domain"], swiftSettings: strict),
    // The UI-free models behind Home (config store, ETA fetching, which commute to show), shared
    // by the iPhone and watch apps. No SwiftUI/MapKit, so it builds for watchOS.
    .target(name: "HomeCore", dependencies: ["Domain"], swiftSettings: strict),
    .target(name: "Features", dependencies: ["Domain", "Mocks", "HomeCore"], swiftSettings: strict),
    .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: strict),
    .testTarget(
      name: "MocksTests", dependencies: ["Mocks", "Domain"],
      resources: [.copy("Resources/sample-config.json")], swiftSettings: strict),
    .testTarget(
      name: "PlatformTests", dependencies: ["Platform", "Domain", "Mocks"], swiftSettings: strict),
    .testTarget(
      name: "HomeCoreTests", dependencies: ["HomeCore", "Domain", "Mocks"], swiftSettings: strict),
    .testTarget(
      name: "FeaturesTests", dependencies: ["Features", "HomeCore", "Domain", "Mocks"],
      swiftSettings: strict),
  ],
  swiftLanguageModes: [.v6]
)
