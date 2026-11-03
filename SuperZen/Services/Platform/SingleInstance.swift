import AppKit

enum SingleInstance {
  static func shouldYield(ownProcessID: pid_t, runningProcessIDs: [pid_t]) -> Bool {
    runningProcessIDs.contains { $0 < ownProcessID }
  }

  static func yieldToRunningInstance() {
    #if !DEBUG
      guard !AppRuntime.isHostingUnitTests, let bundleID = Bundle.main.bundleIdentifier else { return }
      let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
      let ownProcessID = ProcessInfo.processInfo.processIdentifier
      guard shouldYield(ownProcessID: ownProcessID, runningProcessIDs: others.map(\.processIdentifier)) else { return }
      if let url = others.first(where: { $0.processIdentifier != ownProcessID })?.bundleURL {
        NSWorkspace.shared.open(url)
      }
      exit(0)
    #endif
  }
}
