import Foundation
import OSLog
import ServiceManagement

@MainActor
final class LaunchManager {
  static let shared = LaunchManager()

  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "LaunchManager")

  var isEnabled: Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval: return true
    default: return false
    }
  }

  @discardableResult
  func setLaunchAtLogin(_ enabled: Bool) -> Bool {
    guard enabled != isEnabled else { return enabled }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      logger.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
    }
    return isEnabled
  }
}
