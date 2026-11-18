import Domain
import Foundation
import Mocks
import Synchronization
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

/// A transport the tests control: whether it can send, what it sends, and what it "received".
final class FakeTransport: ConfigTransport {
  private struct State {
    var canSend = false
    var lastReceived: Data?
    var sent: [Data] = []
    var failures = 0
  }

  private let state = Mutex(State())

  var canSend: Bool {
    get { state.withLock { $0.canSend } }
    set { state.withLock { $0.canSend = newValue } }
  }
  var lastReceived: Data? {
    get { state.withLock { $0.lastReceived } }
    set { state.withLock { $0.lastReceived = newValue } }
  }
  var sent: [Data] { state.withLock { $0.sent } }
  /// The next `count` sends throw.
  func failNextSends(_ count: Int) { state.withLock { $0.failures = count } }

  struct SendFailed: Error {}

  func send(_ data: Data) throws {
    try state.withLock { state in
      if state.failures > 0 {
        state.failures -= 1
        throw SendFailed()
      }
      state.sent.append(data)
    }
  }
}

struct ConfigSyncEngineTests {
  final class Received: Sendable {
    private let configs = Mutex<[Config]>([])
    var all: [Config] { configs.withLock { $0 } }
    func add(_ config: Config) { configs.withLock { $0.append(config) } }
  }

  struct Fixture {
    let transport = FakeTransport()
    let received = Received()
    let engine: ConfigSyncEngine

    init() {
      let received = received
      engine = ConfigSyncEngine(transport: transport, onReceive: { received.add($0) })
    }

    static func encoded(_ config: Config) throws -> Data { try ConfigSyncCodec.encode(config) }
  }

  private var changed: Config {
    var config = SampleData.config
    config.commutes[0].name = "Renamed"
    return config
  }

  // MARK: Phone side

  @Test func aConfigWaitsUntilTheWatchCanReceiveItThenGoesOutOnActivation() async throws {
    let fixture = Fixture()
    await fixture.engine.publish(SampleData.config)
    #expect(fixture.transport.sent.isEmpty)

    fixture.transport.canSend = true
    fixture.engine.sessionDidActivate()
    #expect(fixture.transport.sent == [try Fixture.encoded(SampleData.config)])
  }

  @Test func onlyTheLatestConfigIsSentAfterSeveralWhileWaiting() async throws {
    let fixture = Fixture()
    await fixture.engine.publish(SampleData.config)
    await fixture.engine.publish(changed)

    fixture.transport.canSend = true
    fixture.engine.sessionDidActivate()
    #expect(fixture.transport.sent == [try Fixture.encoded(changed)])
  }

  @Test func theWatchAppBeingInstalledLaterSendsTheWaitingConfig() async throws {
    let fixture = Fixture()
    fixture.transport.canSend = false
    await fixture.engine.publish(SampleData.config)

    fixture.transport.canSend = true
    fixture.engine.watchStateDidChange()
    #expect(fixture.transport.sent.count == 1)
  }

  @Test func whenReadyAConfigIsSentRightAway() async throws {
    let fixture = Fixture()
    fixture.transport.canSend = true
    await fixture.engine.publish(SampleData.config)
    #expect(fixture.transport.sent == [try Fixture.encoded(SampleData.config)])
  }

  @Test func anUnchangedConfigIsNotSentTwiceButAChangedOneIs() async throws {
    let fixture = Fixture()
    fixture.transport.canSend = true
    await fixture.engine.publish(SampleData.config)
    await fixture.engine.publish(SampleData.config)
    fixture.engine.watchStateDidChange()
    #expect(fixture.transport.sent.count == 1)

    await fixture.engine.publish(changed)
    #expect(fixture.transport.sent.count == 2)
  }

  @Test func aFailedSendIsRetriedOnTheNextChance() async throws {
    let fixture = Fixture()
    fixture.transport.canSend = true
    fixture.transport.failNextSends(1)
    await fixture.engine.publish(SampleData.config)
    #expect(fixture.transport.sent.isEmpty)

    fixture.engine.watchStateDidChange()
    #expect(fixture.transport.sent == [try Fixture.encoded(SampleData.config)])
  }

  // MARK: Watch side

  @Test func aConfigThatArrivesIsHandedOver() throws {
    let fixture = Fixture()
    fixture.engine.receive(try Fixture.encoded(changed))
    #expect(fixture.received.all == [changed])
  }

  @Test func malformedOrMissingDataIsIgnored() {
    let fixture = Fixture()
    fixture.engine.receive(Data("nope".utf8))
    fixture.engine.receive(nil)
    #expect(fixture.received.all.isEmpty)
  }

  @Test func activationPicksUpTheConfigSentBeforeTheWatchAppLaunched() throws {
    let fixture = Fixture()
    fixture.transport.lastReceived = try Fixture.encoded(SampleData.config)
    fixture.engine.sessionDidActivate()
    #expect(fixture.received.all == [SampleData.config])
  }

  @Test func activationWithNothingReceivedHandsOverNothing() {
    let fixture = Fixture()
    fixture.engine.sessionDidActivate()
    #expect(fixture.received.all.isEmpty)
  }
}
