import Foundation

extension StateManager {
  static let shared = StateManager(startsAutomatically: !AppRuntime.isHostingUnitTests)
}
