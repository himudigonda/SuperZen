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
    let actions = manager.menuBar.actions
    switch command {
    case .startBreak:
      guard actions.canStartBreak else { return false }
      manager.startBreak()
    case .skip:
      guard actions.canSkip else { return false }
      manager.skipBreak()
    case .pause(let minutes):
      guard actions.canPause else { return false }
      manager.pause(for: minutes.map { TimeInterval($0) * 60 })
    case .resume:
      guard case .paused(let pause) = manager.session.phase, pause.reason == .user else { return false }
      manager.togglePause()
    case .postpone:
      guard actions.canPostpone else { return false }
      manager.postponeBreak()
    }
    return true
  }

  static func statusDescription(for manager: StateManager) -> String {
    manager.menuBar.glyph.title
  }
}
