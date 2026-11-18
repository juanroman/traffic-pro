/// Where a copy of the config goes whenever it changes: the Apple Watch, which shows the commutes
/// but never edits them. The config holds commute definitions only, never ETAs.
public protocol ConfigSyncSink: Sendable {
  func publish(_ config: Config) async
}
