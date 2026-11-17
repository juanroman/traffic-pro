extension ETAReport {
  /// Builds a report and its one-line summary, formatted as
  /// "Commute: City 31 · Mordor ?", or
  /// "Commute: Couldn't fetch ETAs" when no route could be fetched.
  public init(commute: String, results: [RouteETA]) {
    let message: String
    if !results.isEmpty, results.allSatisfy({ $0.minutes == nil }) {
      message = "\(commute): Couldn't fetch ETAs"
    } else {
      let parts = results.map { "\($0.name) \($0.minutes.map(String.init) ?? "?")" }
      message = "\(commute): " + parts.joined(separator: " · ")
    }
    self.init(commute: commute, message: message, results: results)
  }
}

extension RouteETA {
  /// Whole minutes from seconds, rounded half to even, so a tie such as 90 s
  /// is always rounded the same way.
  public static func minutes(fromSeconds seconds: Int) -> Int {
    Int((Double(seconds) / 60).rounded(.toNearestOrEven))
  }
}
