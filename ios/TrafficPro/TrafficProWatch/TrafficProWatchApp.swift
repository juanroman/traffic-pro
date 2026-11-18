import Domain
import Foundation
import HomeCore
import Platform
import SwiftUI

@main
struct TrafficProWatchApp: App {
  @State private var store: ConfigStore
  /// Receives the commutes from the phone. Held here because `WCSession` only keeps its
  /// delegate weakly.
  private let bridge: WatchConnectivityBridge

  /// The watch keeps its own copy of the commutes (a JSON file, like the phone) and never edits
  /// it: whatever the phone sends replaces it, then the store reloads.
  init() {
    // Application Support always resolves on watchOS; the temporary directory is only a last
    // resort so the app can still launch rather than crash.
    let url =
      (try? FileConfigRepository.defaultURL())
      ?? FileManager.default.temporaryDirectory.appending(path: "config.json")
    let repository = FileConfigRepository(url: url)
    let store = ConfigStore(repository: repository)
    _store = State(initialValue: store)

    let bridge = WatchConnectivityBridge { config in
      Task { @MainActor in
        // A config the phone could not have saved is ignored rather than shown.
        guard (try? await repository.save(config)) != nil else { return }
        await store.load()
      }
    }
    bridge.activate()
    self.bridge = bridge
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .task { await store.load() }
    }
  }
}
