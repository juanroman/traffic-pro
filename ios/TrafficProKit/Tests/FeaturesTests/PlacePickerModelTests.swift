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

  /// The alert clears the flag when it is dismissed; a second failure must raise it again, or the
  /// person would never be told that the second place could not be found.
  @Test func resolveFailureCanBeDismissedAndRaisedAgain() async {
    let model = PlacePickerModel(service: MockPlaceSearchService())
    let missing = PlaceSuggestion(id: "nope", title: "Nope", subtitle: "")
    _ = await model.resolve(missing)
    #expect(model.resolveFailed)

    model.resolveFailed = false
    #expect(model.resolveFailed == false)

    _ = await model.resolve(missing)
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
