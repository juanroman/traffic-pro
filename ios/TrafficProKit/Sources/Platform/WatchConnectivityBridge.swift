#if canImport(WatchConnectivity)
  import Domain
  import Foundation
  import WatchConnectivity

  /// The system side of the phone-to-watch sync: WatchConnectivity's application context. Only
  /// the latest value matters, the system delivers it when the watch is reachable (even if the
  /// watch app was not running), and it is kept for a watch that installs the app later.
  ///
  /// This is a thin adapter: the logic lives in `ConfigSyncEngine`, which is tested with a fake
  /// transport. The same type runs on both sides. On the phone it is a `ConfigSyncSink`; on the
  /// watch `onReceive` gets each config that arrives. Only commute definitions travel, never
  /// ETAs, and nothing is logged.
  public final class WatchConnectivityBridge: NSObject, ConfigSyncSink, Sendable {
    private let engine: ConfigSyncEngine

    public init(onReceive: @escaping @Sendable (Config) -> Void = { _ in }) {
      engine = ConfigSyncEngine(transport: SessionTransport(), onReceive: onReceive)
    }

    public func activate() {
      guard WCSession.isSupported() else { return }
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }

    public func publish(_ config: Config) async {
      await engine.publish(config)
    }
  }

  private struct SessionTransport: ConfigTransport {
    var canSend: Bool {
      #if os(iOS)
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isWatchAppInstalled
      #else
        return false
      #endif
    }

    var lastReceived: Data? {
      WCSession.default.receivedApplicationContext[ConfigSyncCodec.contextKey] as? Data
    }

    func send(_ data: Data) throws {
      #if os(iOS)
        try WCSession.default.updateApplicationContext([ConfigSyncCodec.contextKey: data])
      #endif
    }
  }

  extension WatchConnectivityBridge: WCSessionDelegate {
    public func session(
      _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
      error: (any Error)?
    ) {
      guard activationState == .activated else { return }
      engine.sessionDidActivate()
    }

    public func session(
      _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
      engine.receive(applicationContext[ConfigSyncCodec.contextKey] as? Data)
    }

    #if os(iOS)
      public func sessionDidBecomeInactive(_ session: WCSession) {}

      public func sessionDidDeactivate(_ session: WCSession) {
        // A new watch was paired: start a session for it.
        session.activate()
      }

      public func sessionWatchStateDidChange(_ session: WCSession) {
        engine.watchStateDidChange()
      }
    #endif
  }
#endif
