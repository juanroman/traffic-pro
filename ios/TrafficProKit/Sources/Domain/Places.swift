/// A search hit before it has coordinates. `subtitle` is the address line shown
/// under the name; it is display-only and never saved in the config.
public struct PlaceSuggestion: Hashable, Identifiable, Sendable {
  public let id: String
  public var title: String
  public var subtitle: String

  public init(id: String, title: String, subtitle: String) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
  }
}
