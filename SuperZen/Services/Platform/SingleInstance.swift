import AppKit

enum SingleInstance {
  struct Instance: Equatable {
    var processID: pid_t
    var launchDate: Date?
  }

  private static let quitGracePeriod: TimeInterval = 2

  static func precedes(_ other: Instance, _ own: Instance) -> Bool {
    if let otherLaunch = other.launchDate, let ownLaunch = own.launchDate, otherLaunch != ownLaunch {
      return otherLaunch < ownLaunch
    }
    return other.processID < own.processID
  }

  static func olderInstances(than own: Instance, in running: [Instance]) -> [Instance] {
    running.filter { $0.processID != own.processID && precedes($0, own) }
  }

  static func olderInstances(ownProcessID: pid_t, runningProcessIDs: [pid_t]) -> [pid_t] {
    olderInstances(
      than: Instance(processID: ownProcessID, launchDate: nil),
      in: runningProcessIDs.map { Instance(processID: $0, launchDate: nil) }
    ).map(\.processID)
  }

  static func startDate(ofProcess processID: pid_t) -> Date? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(processID, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
    return Date(
      timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000)
  }

  static func instance(processID: pid_t) -> Instance {
    Instance(processID: processID, launchDate: startDate(ofProcess: processID))
  }

  static func isAlive(_ processID: pid_t) -> Bool {
    kill(processID, 0) == 0
  }

  static func yieldToRunningInstance() {
    #if !DEBUG
      guard !AppRuntime.isHostingUnitTests, let bundleID = Bundle.main.bundleIdentifier else { return }
      let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      let ownProcessID = ProcessInfo.processInfo.processIdentifier
      let older = olderInstances(
        than: instance(processID: ownProcessID),
        in: others.map { instance(processID: $0.processIdentifier) }
      ).map(\.processID)
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
