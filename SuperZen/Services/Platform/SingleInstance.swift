import AppKit

enum SingleInstance {
  private static let quitGracePeriod: TimeInterval = 2

  static func olderInstances(ownProcessID: pid_t, runningProcessIDs: [pid_t]) -> [pid_t] {
    runningProcessIDs.filter { $0 < ownProcessID }
  }

  static func isAlive(_ processID: pid_t) -> Bool {
    kill(processID, 0) == 0
  }

  static func yieldToRunningInstance() {
    #if !DEBUG
      guard !AppRuntime.isHostingUnitTests, let bundleID = Bundle.main.bundleIdentifier else { return }
      let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      let older = olderInstances(
        ownProcessID: ProcessInfo.processInfo.processIdentifier, runningProcessIDs: others.map(\.processIdentifier))
      let deadline = Date().addingTimeInterval(quitGracePeriod)
      while older.contains(where: isAlive), Date() < deadline {
        Thread.sleep(forTimeInterval: 0.1)
      }
      guard let survivor = older.first(where: isAlive) else { return }
      if let url = others.first(where: { $0.processIdentifier == survivor })?.bundleURL {
        NSWorkspace.shared.open(url)
      }
      exit(0)
    #endif
  }
}
