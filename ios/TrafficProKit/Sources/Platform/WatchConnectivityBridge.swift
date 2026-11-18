#if canImport(WatchConnectivity)
  import Domain
  import Foundation
  import Synchronization
  import WatchConnectivity

  /// Carries the config from the phone to the watch with WatchConnectivity's application context:
  /// only the latest value matters, the system delivers it when the watch is reachable (even if
  /// the watch app was not running), and it is kept for a watch that installs the app later.
  ///
  /// The same type runs on both sides. On the phone it is a `ConfigSyncSink`; on the watch
  /// `onReceive` gets each config that arrives (and the last one received before launch).
  /// Only commute definitions travel, never ETAs, and nothing is logged.
  public final class WatchConnectivityBridge: NSObject, ConfigSyncSink, Sendable {
    private let onReceive: @Sendable (Config) -> Void
    /// The latest config, kept until the session is ready to send it (phone side).
    private let pending = Mutex<Data?>(nil)

    public init(onReceive: @escaping @Sendable (Config) -> Void = { _ in }) {
      self.onReceive = onReceive
    }

    public func activate() {
      guard WCSession.isSupported() else { return }
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }

    public func publish(_ config: Config) async {
      guard let data = try? ConfigSyncCodec.encode(config) else { return }
      pending.withLock { $0 = data }
      flush()
    }

    /// Sends the pending config if the session is active and a watch app is there to get it.
    /// Otherwise it stays pending and goes out when the session activates or the watch changes.
    private func flush() {
      #if os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled,
          let data = pending.withLock({ $0 })
        else { return }
        try? session.updateApplicationContext([ConfigSyncCodec.contextKey: data])
      #endif
    }

    private func receive(_ context: [String: Any]) {
      guard
        let data = context[ConfigSyncCodec.contextKey] as? Data,
        let config = try? ConfigSyncCodec.decode(data)
      else { return }
      onReceive(config)
    }
  }

  extension WatchConnectivityBridge: WCSessionDelegate {
    public func session(
      _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
      error: (any Error)?
    ) {
      guard activationState == .activated else { return }
      #if os(iOS)
        flush()
      #else
        // The watch may have been launched after the phone sent its last config.
        receive(session.receivedApplicationContext)
      #endif
    }

    public func session(
      _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
      receive(applicationContext)
    }

    #if os(iOS)
      public func sessionDidBecomeInactive(_ session: WCSession) {}

      public func sessionDidDeactivate(_ session: WCSession) {
        // A new watch was paired: start a session for it.
        session.activate()
      }

      public func sessionWatchStateDidChange(_ session: WCSession) {
        flush()
      }
    #endif
  }
#endif
