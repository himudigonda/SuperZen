import Foundation
import ServiceManagement

class LaunchManager {
  static let shared = LaunchManager()

  /// Modern macOS API for Login Items
  func setLaunchAtLogin(_ enabled: Bool) {
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
