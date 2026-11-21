import Domain
import Mocks
import Testing

@testable import HomeCore

struct RecentPlacesTests {
  private let home = NamedPoint(label: "Home", lat: 19.50, lng: -99.10)
  private let work = NamedPoint(label: "Work", lat: 19.40, lng: -99.20)
  private let gym = NamedPoint(label: "Gym", lat: 19.30, lng: -99.30)

  @Test func noCommutesHaveNoRecents() {
    #expect(RecentPlaces.make(from: []).isEmpty)
  }

  @Test func skipsMissingEndpoints() {
    let commute = Commute(name: "A", origin: home)
    #expect(RecentPlaces.make(from: [commute]) == [home])
  }

  @Test func newestCommuteFirstDestinationBeforeOrigin() {
    let old = Commute(name: "Old", origin: home, destination: work)
    let new = Commute(name: "New", origin: work, destination: gym)
    #expect(RecentPlaces.make(from: [old, new]) == [gym, work, home])
  }

  @Test func samePlaceAppearsOnceWithTheNewestLabel() {
    let renamed = NamedPoint(label: "Office", lat: work.lat, lng: work.lng)
    let old = Commute(name: "Old", origin: home, destination: work)
    let new = Commute(name: "New", origin: home, destination: renamed)
    #expect(RecentPlaces.make(from: [old, new]) == [renamed, home])
  }
}

@MainActor
struct RenamePlaceTests {
  private let home = NamedPoint(label: "Calle A", lat: 19.50, lng: -99.10)
  private let work = NamedPoint(label: "Calle B", lat: 19.40, lng: -99.20)

  private func makeStore() async -> ConfigStore {
    let store = ConfigStore(
      repository: InMemoryConfigRepository(
        initial: Config(commutes: [
          Commute(name: "One", origin: home, destination: work),
          Commute(name: "Two", origin: work, destination: home),
        ])))
    await store.load()
    return store
  }

  @Test func renamesThePlaceInEveryCommuteAndLeavesOthersAlone() async {
    let store = await makeStore()
    await store.renamePlace(at: home.latLng, to: "  Home ")
    let commutes = store.entries.map(\.commute)
    #expect(commutes[0].origin?.label == "Home")
    #expect(commutes[1].destination?.label == "Home")
    #expect(commutes[0].destination?.label == "Calle B")
    #expect(store.recentPlaces.map(\.label) == ["Home", "Calle B"])
  }

  @Test func blankNameOrUnknownPlaceChangesNothing() async {
    let store = await makeStore()
    let before = store.entries
    await store.renamePlace(at: home.latLng, to: "   ")
    await store.renamePlace(at: LatLng(lat: 0, lng: 0), to: "Nowhere")
    #expect(store.entries == before)
  }
}
