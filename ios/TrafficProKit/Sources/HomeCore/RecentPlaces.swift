import Domain

/// The places offered in the picker's "Recent" list: every origin and destination of the
/// user's commutes, so a place that was typed once can be reused without searching again.
public enum RecentPlaces {
  /// Newest commute first, destination before origin (the place you arrive at is the one you
  /// most likely want next). Two places are the same when their coordinates match; the label
  /// of the first one found wins, so a renamed place shows up under its latest name.
  /// `saved` (the old Home/Work shortcuts) go last, so they stay reachable after the update.
  public static func make(from commutes: [Commute], saved: SavedPlaces = SavedPlaces())
    -> [NamedPoint]
  {
    let fromCommutes = commutes.reversed().flatMap { [$0.destination, $0.origin] }
    let fromSaved = [saved.home?.point, saved.work?.point]
    var seen = Set<LatLng>()
    return (fromCommutes + fromSaved).compactMap { $0 }.filter { seen.insert($0.latLng).inserted }
  }
}
