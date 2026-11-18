import Foundation
import Testing

private struct Unit: Decodable {
  let state: String
  let value: String
}

private struct Localization: Decodable {
  let stringUnit: Unit?
}

private struct Entry: Decodable {
  let localizations: [String: Localization]?
}

private struct Catalog: Decodable {
  let strings: [String: Entry]
}

/// Guards the hand-maintained string catalogs. The UI lives in the `TrafficProKit` package, whose
/// strings Xcode does not extract into the app's catalog, so nothing else notices a missing
/// translation or a placeholder that was dropped or reordered in one.
struct LocalizationCatalogTests {
  private static let language = "es-MX"

  /// The app targets that own catalogs: the phone app and the watch app.
  private static let targets = ["TrafficPro", "TrafficProWatch"]

  private static func load(_ name: String, in target: String = "TrafficPro") throws -> Catalog {
    // The catalogs are compiled into .strings files in the app bundle, so read the sources.
    let folder = URL(filePath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appending(path: target)
    let data = try Data(contentsOf: folder.appending(path: name))
    return try JSONDecoder().decode(Catalog.self, from: data)
  }

  /// "%@", "%lld", "%1$@" and so on, in positional order, so `%2$@ … %1$@` still matches.
  private static func placeholders(_ text: String) -> [String] {
    let pattern = /%(?:(\d+)\$)?(lld|@|d|f)/
    let found = text.matches(of: pattern).enumerated().map { index, match in
      (position: match.output.1.flatMap { Int($0) } ?? index + 1, kind: String(match.output.2))
    }
    return found.sorted { $0.position < $1.position }.map(\.kind)
  }

  @Test func everyKeyIsTranslated() throws {
    for target in Self.targets {
      for name in ["Localizable.xcstrings", "InfoPlist.xcstrings"] {
        let catalog = try Self.load(name, in: target)
        #expect(!catalog.strings.isEmpty, "\(target)/\(name) is empty")
        for (key, entry) in catalog.strings {
          let unit = entry.localizations?[Self.language]?.stringUnit
          #expect(unit?.state == "translated", "\(target)/\(name): “\(key)” is not translated")
          #expect(
            unit?.value.isEmpty == false, "\(target)/\(name): “\(key)” has an empty translation")
        }
      }
    }
  }

  @Test func translationsKeepTheirPlaceholders() throws {
    let catalog = try Self.load("Localizable.xcstrings")
    for (key, entry) in catalog.strings {
      guard let value = entry.localizations?[Self.language]?.stringUnit?.value else { continue }
      #expect(
        Self.placeholders(value) == Self.placeholders(key),
        "“\(key)” and its translation take different arguments")
    }
  }

  /// An Info.plist key has no English text of its own to fall back on: without an `en` entry
  /// Xcode writes the key's own name as the English value, and App Store Connect rejects that
  /// (90738, "Invalid purpose string value").
  @Test func infoPlistStringsHaveAnEnglishValue() throws {
    for target in Self.targets {
      let catalog = try Self.load("InfoPlist.xcstrings", in: target)
      for (key, entry) in catalog.strings {
        let value = entry.localizations?["en"]?.stringUnit?.value
        #expect(value?.isEmpty == false, "\(target)/InfoPlist.xcstrings: “\(key)” has no English")
        #expect(value != key, "\(target)/InfoPlist.xcstrings: “\(key)” is its own English")
      }
    }
  }

  @Test func locationPromptIsTranslated() throws {
    let catalog = try Self.load("InfoPlist.xcstrings")
    #expect(catalog.strings["NSLocationWhenInUseUsageDescription"] != nil)
  }
}
