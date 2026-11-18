import Domain
import Foundation
import HomeCore
import Mocks
import Platform
import SwiftUI

@main
struct TrafficProWatchApp: App {
  @State private var store: ConfigStore
  @State private var home: HomeModel
  /// Receives the commutes from the phone. Held here because `WCSession` only keeps its
  /// delegate weakly. Nil under `-mock-services`.
  private let bridge: WatchConnectivityBridge?

  /// The watch keeps its own copy of the commutes (a JSON file, like the phone) and never edits
  /// it: whatever the phone sends replaces it, then the store reloads. ETAs come straight from
  /// Google, like on the phone; nothing about them is kept. `-mock-services` swaps everything
  /// for the offline sample data, with the user standing at "Home", to see the screens in a
  /// simulator without spending Google calls.
  init() {
    let useMocks = CommandLine.arguments.contains("-mock-services")
    let repository: any ConfigRepository =
      useMocks ? InMemoryConfigRepository() : Self.fileRepository()
    let store = ConfigStore(repository: repository)

    let home: HomeModel
    if useMocks {
      home = HomeModel(
        store: store, service: MockETAService(repository: repository),
        location: FixedLocationProvider(
          authorization: .authorized, location: SampleData.home.latLng),
        recents: InMemoryRecentCommutesRepository(), prompts: InMemoryLocationPromptRepository())
      bridge = nil
    } else {
      home = HomeModel(
        store: store,
        service: CachedETAService(
          wrapping: GoogleETAService(client: GoogleRoutesClient(), repository: repository)),
        // Where the user is only picks which commute to show; it never leaves the device.
        location: CoreLocationProvider(),
        recents: UserDefaultsRecentCommutesRepository(),
        prompts: UserDefaultsLocationPromptRepository())
      let bridge = WatchConnectivityBridge { config in
        Task { @MainActor in
          // A config the phone could not have saved is ignored rather than shown.
          guard (try? await repository.save(config)) != nil else { return }
          await store.load()
          await home.reopenIfNeeded()
        }
      }
      bridge.activate()
      self.bridge = bridge
    }
    _store = State(initialValue: store)
    _home = State(initialValue: home)
  }

  var body: some Scene {
    WindowGroup {
      GlanceView(store: store, model: home)
        .task {
          await store.load()
          await home.open()
        }
    }
  }

  private static func fileRepository() -> FileConfigRepository {
    // Application Support always resolves on watchOS; the temporary directory is only a last
    // resort so the app can still launch rather than crash.
    let url =
      (try? FileConfigRepository.defaultURL())
      ?? FileManager.default.temporaryDirectory.appending(path: "config.json")
    return FileConfigRepository(url: url)
  }
}
