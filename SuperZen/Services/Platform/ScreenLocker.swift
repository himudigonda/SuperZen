import CoreGraphics
import Foundation
import OSLog

@MainActor
protocol ScreenLocking {
  func lock(then report: @escaping @MainActor (Bool) -> Void)
}

@MainActor
struct SystemScreenLocker: ScreenLocking {
  private static let loginFramework =
    "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SuperZen", category: "lock")

  static let confirmationDelay: TimeInterval = 3

  func lock(then report: @escaping @MainActor (Bool) -> Void) {
    guard Self.lockWithLoginFramework() || Self.sleepDisplay() else {
      Self.logger.error("No screen lock strategy succeeded")
      report(false)
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.confirmationDelay) {
      MainActor.assumeIsolated { report(Self.isScreenLocked) }
    }
  }

  static var isScreenLocked: Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return session["CGSSessionScreenIsLocked"] as? Bool ?? false
  }

  private static func lockWithLoginFramework() -> Bool {
    guard let handle = dlopen(loginFramework, RTLD_NOW) else {
      logger.notice("login.framework unavailable")
      return false
    }
    defer { dlclose(handle) }
    guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
      logger.notice("SACLockScreenImmediate missing")
      return false
    }
    typealias LockFunction = @convention(c) () -> Int32
    let lock = unsafeBitCast(symbol, to: LockFunction.self)
    return lock() == 0
  }

  private static func sleepDisplay() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["displaysleepnow"]
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      logger.error("pmset failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }
}
