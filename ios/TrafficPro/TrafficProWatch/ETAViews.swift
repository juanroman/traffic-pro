import Domain
import HomeCore
import SwiftUI

/// The chips for the commute on screen, or why there are none.
struct ETAContent: View {
  let model: ETAModel
  let commute: Commute
  let retry: () async -> Void

  var body: some View {
    switch model.state {
    case .idle, .loading:
      ProgressView("Checking traffic…")
        .frame(maxWidth: .infinity)
    case .failed(let message):
      failure(message)
    case .loaded(let report, let fetchedAt):
      if report.allFailed {
        failure(
          String(localized: "Couldn't fetch ETAs."),
          detail: report.results.compactMap(\.error).first)
      } else {
        // The previous numbers stay while a pull to refresh is in flight, dimmed so they are not
        // mistaken for the new ones.
        ETACard(commute: commute, report: report, isDimmed: model.isRefreshing)
        Footer(fetchedAt: fetchedAt)
      }
    }
  }

  private func failure(_ message: String, detail: String? = nil) -> some View {
    VStack(spacing: 6) {
      Label(message, systemImage: "exclamationmark.triangle")
        .font(.footnote)
      if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
      Button("Try Again") { Task { await retry() } }
    }
  }
}

/// The Routes numbers and their credit in one bordered container, so Google's data is visibly
/// apart from our own text ("Updated…", "Near Home") and the credit is never separated from it.
struct ETACard: View {
  let commute: Commute
  let report: ETAReport
  /// Dims the numbers (not the credit, which must stay legible) while fresh ones are on the way.
  var isDimmed = false

  var body: some View {
    VStack(spacing: 0) {
      // One chip per route in the commute's own order (never sorted: the colour drawn on the
      // phone's map is the colour read here), with only the quickest marked "Fastest".
      VStack(spacing: 6) {
        ForEach(report.results, id: \.name) { result in
          ETAChip(
            result: result,
            color: commute.routes.first { $0.name == result.name }.map { Color(hex: $0.color) }
              ?? .gray,
            isFastest: result.name == report.fastestRouteName && report.results.count > 1)
        }
      }
      .opacity(isDimmed ? 0.4 : 1)
      .animation(.default, value: isDimmed)
      .padding(6)
      GoogleMapsAttribution()
    }
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("eta-card")
  }
}

struct ETAChip: View {
  let result: RouteETA
  let color: Color
  let isFastest: Bool

  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 10, height: 10)
      VStack(alignment: .leading, spacing: 0) {
        Text(result.name).font(.footnote.bold())
        if isFastest { Text("Fastest").font(.caption2).foregroundStyle(.green) }
        if let error = result.error { Text(error).font(.caption2).foregroundStyle(.secondary) }
      }
      Spacer(minLength: 4)
      if let minutes = result.minutes {
        Text("\(minutes) min").font(.title3.bold())
      } else {
        Text(verbatim: "?").font(.title3.bold())
      }
    }
    .padding(8)
    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("eta-\(result.name)")
  }
}

/// Google's terms require credit wherever Routes data is shown without a Google map. Same logo
/// and rules as the phone (`GoogleMapsAttributionStyle`), at the guide's smallest height.
struct GoogleMapsAttribution: View {
  /// The guide allows 16 to 19 points; the logo artwork is 98 x 18, never stretched.
  private let logoHeight: CGFloat = 16
  private let aspectRatio: CGFloat = 98.0 / 18.0

  var body: some View {
    Image("GoogleMapsLogo")
      .resizable()
      .aspectRatio(aspectRatio, contentMode: .fit)
      .frame(height: logoHeight)
      // The guide's minimum clear space around the logo.
      .padding(EdgeInsets(top: 10, leading: 10, bottom: 5, trailing: 10))
      .accessibilityElement()
      .accessibilityLabel(Text(verbatim: "Google Maps"))
      .accessibilityAddTraits(.isImage)
      .accessibilityIdentifier("google-attribution")
  }
}

/// "Updated 12 s ago". Ours, so it sits outside the card that holds Google's data.
struct Footer: View {
  let fetchedAt: Date

  var body: some View {
    TimelineView(RelativeAgeSchedule(since: fetchedAt)) { context in
      Text("Updated \(RelativeAge.text(since: fetchedAt, now: context.date, style: .short))")
        .accessibilityIdentifier("glance-updated")
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }
}

/// Shown once, before the system prompt, so the request makes sense when it arrives.
struct LocationExplainer: View {
  let allow: () -> Void
  let decline: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        Image(systemName: "location.circle.fill")
          .font(.title)
          .foregroundStyle(.tint)
        Text("Show the commute that starts where you are")
          .font(.headline)
          .multilineTextAlignment(.center)
        Text("Your location stays on this device. It's only used to pick which commute to show.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Continue", action: allow)
          .accessibilityIdentifier("location-continue")
        Button("Not now", action: decline)
          .accessibilityIdentifier("location-not-now")
      }
    }
  }
}
