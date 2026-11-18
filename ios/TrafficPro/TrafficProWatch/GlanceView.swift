import Domain
import HomeCore
import SwiftUI

/// The watch's one screen: the ETAs of the commute `HomeModel` picked (the one that starts where
/// you are, else the last viewed), refreshed whenever the app opens or comes back.
struct GlanceView: View {
  let store: ConfigStore
  let model: HomeModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var isChoosing = false

  var body: some View {
    content
      .onChange(of: scenePhase) {
        if scenePhase == .active { Task { await model.reopenIfNeeded() } }
      }
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .resolving:
      ProgressView("Checking traffic…")
    case .empty:
      ContentUnavailableView(
        "No commutes yet", systemImage: "car",
        description: Text("Open Traffic Pro on your iPhone to add a commute."))
    case .askingPermission:
      LocationExplainer(
        allow: { Task { await model.allowLocation() } },
        decline: { Task { await model.declineLocation() } })
    case .ready:
      ready
    }
  }

  private var ready: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        header
        ReasonLine(reason: model.reason)
        if let eta = model.eta, let commute {
          ETAContent(model: eta, commute: commute, retry: { await model.retry() })
        }
      }
    }
    .refreshable { await model.refresh() }
  }

  /// The commute's name; with 2+ commutes it is a button that lets you pick another one.
  @ViewBuilder private var header: some View {
    if let name = model.selectedName {
      if names.count > 1 {
        Button {
          isChoosing = true
        } label: {
          Text("\(name) \(Image(systemName: "chevron.down"))").font(.headline)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("glance-selector")
        .sheet(isPresented: $isChoosing) {
          CommutePicker(names: names, selected: name) { chosen in
            Task { await model.select(chosen) }
          }
        }
      } else {
        Text(name).font(.headline)
      }
    }
  }

  private var names: [String] { store.entries.map(\.commute.name) }

  private var commute: Commute? {
    store.entries.first { $0.commute.name == model.selectedName }?.commute
  }
}

/// "Near Home" / "Last viewed": says why this commute is the one on screen.
private struct ReasonLine: View {
  let reason: HomeSelection.Reason?

  var body: some View {
    switch reason {
    case .near(let label):
      line("Near \(label)", symbol: "location.fill")
    case .lastViewed:
      line("Last viewed", symbol: "clock")
    case .firstInList, nil:
      EmptyView()
    }
  }

  private func line(_ text: LocalizedStringKey, symbol: String) -> some View {
    Label(text, systemImage: symbol)
      .font(.footnote)
      .foregroundStyle(.secondary)
  }
}

/// The commutes to choose from, with the current one checked. Choosing closes it.
private struct CommutePicker: View {
  let names: [String]
  let selected: String
  let choose: (String) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(names, id: \.self) { name in
        Button {
          choose(name)
          dismiss()
        } label: {
          HStack {
            Text(name)
            Spacer()
            if name == selected { Image(systemName: "checkmark") }
          }
        }
      }
      .navigationTitle("Commute")
    }
  }
}
