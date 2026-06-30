import Foundation
import ServiceManagement

class LaunchManager {
  static let shared = LaunchManager()

  /// Modern macOS API for Login Items.
  /// Idempotent: skips the call when the service is already in the desired state, so
  /// reconciling on onboarding-finish (or repeated toggles) never throws/logs spuriously.
  func setLaunchAtLogin(_ enabled: Bool) {
    let isEnabled = SMAppService.mainApp.status == .enabled
    guard enabled != isEnabled else { return }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      print("Failed to update launch item: \(error)")
    }
  }
}
