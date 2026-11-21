import Domain
import SwiftUI

/// Origin/destination picker modeled on Calendar's Location field (search with
/// name + address results). While the search box is empty it lists the places from the
/// user's other commutes, so a place is typed once and reused.
struct PlacePickerView: View {
  let title: String
  let selected: NamedPoint?
  let recents: [NamedPoint]
  let onSelect: (NamedPoint?) -> Void

  @State private var model: PlacePickerModel
  @State private var query = ""
  @Environment(\.dismiss) private var dismiss

  init(
    title: String, selected: NamedPoint?, service: any PlaceSearchService,
    recents: [NamedPoint], onSelect: @escaping (NamedPoint?) -> Void
  ) {
    self.title = title
    self.selected = selected
    self.recents = recents
    self.onSelect = onSelect
    _model = State(initialValue: PlacePickerModel(service: service))
  }

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      List {
        if query.isEmpty && !recents.isEmpty {
          Section("Recent") {
            ForEach(recents, id: \.self) { place in
              Button {
                choose(place)
              } label: {
                Label(place.label, systemImage: "mappin.circle.fill")
              }
              .foregroundStyle(.primary)
              .accessibilityIdentifier("recent-\(place.label)")
            }
          }
        }

        if selected != nil {
          Button("Clear \(title)", role: .destructive) { choose(nil) }
        }

        results
      }
      .searchable(text: $query, prompt: "Search places")
      .task(id: query) { await model.update(query: query) }
      .navigationTitle(title)
      .inlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .alert("Couldn't find that place", isPresented: $model.resolveFailed) {
        Button("OK", role: .cancel) {}
      }
    }
  }

  @ViewBuilder private var results: some View {
    if model.failed {
      ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle")
    } else if !query.isEmpty && model.suggestions.isEmpty {
      ContentUnavailableView.search(text: query)
    } else {
      ForEach(model.suggestions) { suggestion in
        Button {
          Task { await pick(suggestion) }
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(suggestion.title)
            if !suggestion.subtitle.isEmpty {
              Text(suggestion.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
          }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier("place-\(suggestion.title)")
      }
    }
  }

  private func pick(_ suggestion: PlaceSuggestion) async {
    guard let point = await model.resolve(suggestion) else { return }
    choose(point)
  }

  private func choose(_ place: NamedPoint?) {
    onSelect(place)
    dismiss()
  }
}
