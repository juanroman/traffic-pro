import Domain
import Foundation

/// How the config travels between the phone and the watch: the same JSON as the config file,
/// under one key of the WatchConnectivity application context. The key carries a version so a
/// future shape can change without older watches misreading it.
public enum ConfigSyncCodec {
  public static let contextKey = "config.v1"

  public static func encode(_ config: Config) throws -> Data {
    let encoder = JSONEncoder()
    // Stable bytes for equal configs, so an unchanged config is not sent again.
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(config)
  }

  public static func decode(_ data: Data) throws -> Config {
    try JSONDecoder().decode(Config.self, from: data)
  }
}
