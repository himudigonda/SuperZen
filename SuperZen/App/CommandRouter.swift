import Foundation
import SuperZenCore

@MainActor
enum CommandRouter {
  @discardableResult
  static func handle(_ url: URL, on manager: StateManager, defaults: UserDefaults = .standard) -> Bool {
    guard let command = RemoteCommand(url: url) else { return false }
    return perform(command, on: manager, defaults: defaults)
  }

  @discardableResult
  static func perform(_ command: RemoteCommand, on manager: StateManager, defaults: UserDefaults = .standard) -> Bool {
    guard defaults.bool(forKey: SettingKey.hasCompletedOnboarding) else { return false }
    switch command {
    case .startBreak:
      manager.startBreak()
    case .skip:
      manager.skipBreak()
    case .pause(let minutes):
      manager.pause(for: minutes.map { TimeInterval($0) * 60 })
    case .resume:
      guard case .paused(let pause) = manager.session.phase, pause.reason == .user else { return false }
      manager.togglePause()
    case .postpone:
      manager.postponeBreak()
    }
    return true
  }

  static func statusDescription(for manager: StateManager) -> String {
    switch manager.status {
    case .active: String(localized: "Focusing")
    case .nudge: String(localized: "Break coming up")
    case .onBreak: String(localized: "On a break")
    case .wellness: String(localized: "Wellness reminder")
    case .paused: String(localized: "Paused")
    }
  }
}
