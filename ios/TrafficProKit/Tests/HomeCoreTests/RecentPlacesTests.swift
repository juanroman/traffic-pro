import Domain
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

  @Test func legacySavedPlacesGoLastAndAreNotDuplicated() {
    let saved = SavedPlaces(
      home: SavedPlace(point: home, detail: ""), work: SavedPlace(point: gym, detail: ""))
    let commute = Commute(name: "A", origin: home, destination: work)
    #expect(RecentPlaces.make(from: [commute], saved: saved) == [work, home, gym])
  }
}
