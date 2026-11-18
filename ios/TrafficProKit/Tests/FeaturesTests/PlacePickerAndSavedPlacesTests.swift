import Domain
import Foundation
import HomeCore
import Mocks
import Testing

@testable import Features

@MainActor
struct PlacePickerModelTests {
  @Test func emptyQueryHasNoSuggestions() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "")
    #expect(model.suggestions.isEmpty)
  }

  @Test func queryFiltersIgnoringCaseAndAccents() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "satelite")
    #expect(model.suggestions.map(\.title) == ["Satélite"])
  }

  @Test func resolveReturnsCoordinates() async throws {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    await model.update(query: "polanco")
    let suggestion = try #require(model.suggestions.first)
    let point = await model.resolve(suggestion)
    #expect(point?.label == "Polanco")
    #expect(model.resolveFailed == false)
  }

  @Test func resolveFailureIsReported() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    let point = await model.resolve(PlaceSuggestion(id: "nope", title: "Nope", subtitle: ""))
    #expect(point == nil)
    #expect(model.resolveFailed)
  }

  @Test func searchFailureIsReported() async {
    struct Broken: PlaceSearchService {
      func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        throw PlaceSearchError.notFound
      }
      func resolve(_ suggestion: PlaceSuggestion) async throws -> NamedPoint {
        throw PlaceSearchError.notFound
      }
    }
    let model = PlacePickerModel(service: Broken())
    await model.update(query: "x")
    #expect(model.failed)
    #expect(model.suggestions.isEmpty)
  }
}

@MainActor
struct SavedPlacesStoreTests {
  @Test func startsUnset() async {
    let store = SavedPlacesStore(repository: InMemorySavedPlacesRepository())
    await store.load()
    #expect(store.places == SavedPlaces())
  }

  @Test func setForcesTheKeywordLabelAndPersists() async throws {
    let repository = InMemorySavedPlacesRepository()
    let store = SavedPlacesStore(repository: repository)
    let found = NamedPoint(label: "Calle Amores 12", lat: 19.4, lng: -99.1)

    let saved = await store.set(.home, to: found, detail: "Del Valle, CDMX")
    #expect(saved == NamedPoint(label: "Home", lat: 19.4, lng: -99.1))
    #expect(store.places.home?.detail == "Del Valle, CDMX")
    #expect(store.places.work == nil)
    #expect(try await repository.load().home == store.places.home)
  }

  @Test func changingAShortcutDoesNotTouchExistingCommutes() async throws {
    let configStore = ConfigStore(repository: InMemoryConfigRepository())
    await configStore.load()
    let id = try #require(configStore.entries.first?.id)
    let places = SavedPlacesStore(repository: InMemorySavedPlacesRepository())

    let first = try #require(
      await places.set(.work, to: NamedPoint(label: "A", lat: 1, lng: 2), detail: ""))
    await configStore.updateCommute(id: id) { $0.origin = first }
    await places.set(.work, to: NamedPoint(label: "B", lat: 5, lng: 6), detail: "")

    #expect(configStore.entry(id: id)?.commute.origin == NamedPoint(label: "Work", lat: 1, lng: 2))
  }
}
