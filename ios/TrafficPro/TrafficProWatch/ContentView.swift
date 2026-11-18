import Domain
import HomeCore
import Mocks
import SwiftUI

/// For now only the commutes the phone sent, as proof that the sync works. The ETAs come next.
struct ContentView: View {
  let store: ConfigStore

  var body: some View {
    NavigationStack {
      if store.entries.isEmpty {
        ContentUnavailableView(
          "No commutes yet", systemImage: "car",
          description: Text("Open Traffic Pro on your iPhone to add a commute."))
      } else {
        List(store.entries) { entry in
          Text(entry.commute.name)
        }
        .navigationTitle("Traffic Pro")
      }
    }
  }
}

#Preview {
  ContentView(store: ConfigStore(repository: InMemoryConfigRepository()))
}
