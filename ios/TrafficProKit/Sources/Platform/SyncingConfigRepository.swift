import Domain

/// Wraps the phone's config repository and hands every config that was loaded or saved to a
/// `ConfigSyncSink`. Loading counts too: it makes the watch receive the commutes the first time
/// the phone app opens, without waiting for an edit. Nothing is published when a save fails or
/// is rejected, so the watch never gets a config the phone does not have.
public struct SyncingConfigRepository: ConfigRepository {
  private let base: any ConfigRepository
  private let sink: any ConfigSyncSink

  public init(wrapping base: any ConfigRepository, sink: any ConfigSyncSink) {
    self.base = base
    self.sink = sink
  }

  public func load() async throws -> Config {
    let config = try await base.load()
    await sink.publish(config)
    return config
  }

  public func save(_ config: Config) async throws {
    try await base.save(config)
    await sink.publish(config)
  }
}
