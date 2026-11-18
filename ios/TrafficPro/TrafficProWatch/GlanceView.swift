import Domain
import HomeCore
import SwiftUI

/// The watch's one screen: the ETAs of the commute `HomeModel` picked (the one that starts where
/// you are, else the last viewed), refreshed whenever the app opens or comes back.
struct GlanceView: View {
  let store: ConfigStore
  let model: HomeModel
  @Environment(\.scenePhase) private var scenePhase

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
        if let name = model.selectedName { Text(name).font(.headline) }
        ReasonLine(reason: model.reason)
        if let eta = model.eta, let commute {
          ETAContent(model: eta, commute: commute, retry: { await model.retry() })
        }
      }
    }
    .refreshable { await model.refresh() }
  }

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
