import Foundation
import OSLog
import ServiceManagement

@MainActor
protocol LoginItemService {
  var isEnabled: Bool { get }
  func register() throws
  func unregister() throws
}

@MainActor
struct SystemLoginItem: LoginItemService {
  var isEnabled: Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval: return true
    default: return false
    }
  }

  func register() throws { try SMAppService.mainApp.register() }
  func unregister() throws { try SMAppService.mainApp.unregister() }
}

@MainActor
final class LaunchManager {
  static let shared = LaunchManager()

  private let service: any LoginItemService
  private let location: () -> InstallLocation
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "LaunchManager")

  init(
    service: (any LoginItemService)? = nil,
    location: @escaping () -> InstallLocation = { .current }
  ) {
    self.service = service ?? SystemLoginItem()
    self.location = location
  }

  var isEnabled: Bool { service.isEnabled }

  var unavailableReason: String? { location().launchAtLoginExplanation }

  @discardableResult
  func setLaunchAtLogin(_ enabled: Bool) -> Bool {
    if enabled, !location().allowsLaunchAtLogin {
      logger.notice("Launch at login refused: app is not running from an installed location")
      return isEnabled
    }
    guard enabled != isEnabled else { return enabled }
    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      logger.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
    }
    return isEnabled
  }
}
