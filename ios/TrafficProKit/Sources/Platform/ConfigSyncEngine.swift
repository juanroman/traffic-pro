import Domain
import Foundation
import Synchronization

/// The few things the sync needs from the system's phone-to-watch channel, so the logic around
/// it can be tested without a paired phone and watch. `WatchConnectivityBridge` is the real one.
public protocol ConfigTransport: Sendable {
  /// True when a send can reach a watch app: the session is active and the watch app is
  /// installed. Always false on the watch itself.
  var canSend: Bool { get }
  /// The last config the other side delivered, if any (read on the watch at launch).
  var lastReceived: Data? { get }
  func send(_ data: Data) throws
}

/// The logic of the phone-to-watch sync, apart from the system session.
///
/// - Only the latest config matters: publishing again replaces one that was not sent yet.
/// - Nothing is sent until the transport can reach a watch app; the config waits, and goes out
///   when the session activates or the watch's state changes (for example the app gets installed).
/// - An unchanged config is not sent twice, and a failed send is retried on the next chance.
/// - Whatever arrives is decoded; malformed data is ignored rather than becoming an empty config.
public final class ConfigSyncEngine: ConfigSyncSink, Sendable {
  private struct State {
    var pending: Data?
    var lastSent: Data?
  }

  private let transport: any ConfigTransport
  private let onReceive: @Sendable (Config) -> Void
  private let state = Mutex(State())

  public init(
    transport: any ConfigTransport, onReceive: @escaping @Sendable (Config) -> Void = { _ in }
  ) {
    self.transport = transport
    self.onReceive = onReceive
  }

  public func publish(_ config: Config) async {
    guard let data = try? ConfigSyncCodec.encode(config) else { return }
    state.withLock { $0.pending = data }
    flush()
  }

  /// The session finished activating. On the phone this sends what was waiting; on the watch it
  /// picks up the config the phone sent before the watch app launched.
  public func sessionDidActivate() {
    flush()
    receive(transport.lastReceived)
  }

  /// The watch was paired, or its app was installed or removed.
  public func watchStateDidChange() {
    flush()
  }

  public func receive(_ data: Data?) {
    guard let data, let config = try? ConfigSyncCodec.decode(data) else { return }
    onReceive(config)
  }

  private func flush() {
    let data = state.withLock { state -> Data? in
      guard let pending = state.pending, pending != state.lastSent else { return nil }
      return pending
    }
    guard let data, transport.canSend else { return }
    // A failure leaves `lastSent` alone, so the next chance tries again.
    guard (try? transport.send(data)) != nil else { return }
    state.withLock { $0.lastSent = data }
  }
}
