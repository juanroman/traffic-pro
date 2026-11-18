import Domain
import Foundation
import Mocks
import Testing

@testable import Platform

actor RecordingSink: ConfigSyncSink {
  private(set) var published: [Config] = []
  func publish(_ config: Config) { published.append(config) }
}

struct ConfigSyncCodecTests {
  @Test func aConfigSurvivesTheTrip() throws {
    let config = SampleData.config
    let decoded = try ConfigSyncCodec.decode(ConfigSyncCodec.encode(config))
    #expect(decoded == config)
  }

  @Test func equalConfigsEncodeToTheSameBytes() throws {
    let first = try ConfigSyncCodec.encode(SampleData.config)
    let second = try ConfigSyncCodec.encode(SampleData.config)
    #expect(first == second)
  }

  @Test func garbageIsRejectedInsteadOfBecomingAnEmptyConfig() {
    #expect(throws: (any Error).self) { try ConfigSyncCodec.decode(Data("nope".utf8)) }
  }
}

struct SyncingConfigRepositoryTests {
  struct Fixture {
    let repository: SyncingConfigRepository
    let base = InMemoryConfigRepository()
    let sink = RecordingSink()

    init() {
      repository = SyncingConfigRepository(wrapping: base, sink: sink)
    }
  }

  @Test func savingStoresAndPublishesTheSameConfig() async throws {
    let fixture = Fixture()
    var config = SampleData.config
    config.commutes[0].name = "Renamed"
    try await fixture.repository.save(config)
    #expect(try await fixture.base.load() == config)
    #expect(await fixture.sink.published == [config])
  }

  @Test func loadingPublishesWhatItLoaded() async throws {
    let fixture = Fixture()
    let loaded = try await fixture.repository.load()
    #expect(loaded == (try await fixture.base.load()))
    #expect(await fixture.sink.published == [loaded])
  }

  @Test func aRejectedSaveIsNotPublished() async throws {
    let fixture = Fixture()
    var invalid = SampleData.config
    invalid.commutes[0].name = ""
    await #expect(throws: ConfigRepositoryError.self) {
      try await fixture.repository.save(invalid)
    }
    #expect(await fixture.sink.published.isEmpty)
  }
}
