import Combine
import Foundation
import SuperZenCore

@MainActor
protocol HotkeyRegistering: AnyObject {
  var onPress: ((HotkeyAction) -> Void)? { get set }
  func register(_ hotkey: Hotkey, for action: HotkeyAction) -> Bool
  func unregisterAll()
  func systemReservedHotkeys() -> Set<Hotkey>
}

@MainActor
final class HotkeyCenter: ObservableObject {
  @Published private(set) var statuses: [HotkeyAction: HotkeyStatus] = [:]
  var onAction: ((HotkeyAction) -> Void)?

  private let registrar: any HotkeyRegistering
  private let defaults: UserDefaults
  private var registered: [HotkeyAction: String]?

  init(registrar: any HotkeyRegistering, defaults: UserDefaults) {
    self.registrar = registrar
    self.defaults = defaults
    registrar.onPress = { [weak self] action in self?.onAction?(action) }
  }

  func reload() {
    let combos = Self.combos(in: defaults)
    guard combos != registered else { return }
    registered = combos
    registrar.unregisterAll()
    var plan = preview(combos)
    for (action, status) in plan {
      guard let hotkey = status.hotkey, !registrar.register(hotkey, for: action) else { continue }
      plan[action] = .blocked(.unavailable)
    }
    statuses = plan
  }

  func preview(_ combos: [HotkeyAction: String]) -> [HotkeyAction: HotkeyStatus] {
    HotkeyPlan.resolve(combos, reserved: registrar.systemReservedHotkeys())
  }

  static func combos(in defaults: UserDefaults) -> [HotkeyAction: String] {
    Dictionary(
      uniqueKeysWithValues: HotkeyAction.allCases.map {
        ($0, defaults.string(forKey: $0.settingKey) ?? $0.defaultCombo)
      })
  }
}

extension HotkeyAction {
  var settingKey: String {
    switch self {
    case .startBreak: return SettingKey.shortcutStartBreak
    case .togglePause: return SettingKey.shortcutTogglePause
    case .skipBreak: return SettingKey.shortcutSkipBreak
    }
  }

  var defaultCombo: String {
    switch self {
    case .startBreak: return SettingsCatalog.shortcutStartBreakDefault
    case .togglePause: return SettingsCatalog.shortcutTogglePauseDefault
    case .skipBreak: return SettingsCatalog.shortcutSkipBreakDefault
    }
  }
}

extension HotkeyIssue {
  var message: String {
    switch self {
    case .unrecognized:
      return String(localized: "This key can't be used for a shortcut.", comment: "Shortcut issue")
    case .needsModifier:
      return String(localized: "Add ⌘, ⌥ or ⌃ to this shortcut.", comment: "Shortcut issue")
    case .duplicate(let other):
      return String(localized: "Already used by \(other.title).", comment: "Shortcut issue: duplicate")
    case .reservedBySystem:
      return String(localized: "macOS already uses this shortcut.", comment: "Shortcut issue")
    case .unavailable:
      return String(localized: "Another app has claimed this shortcut.", comment: "Shortcut issue")
    }
  }
}

extension HotkeyAction {
  var title: String {
    switch self {
    case .startBreak: return String(localized: "Start break now", comment: "Keyboard shortcut row title")
    case .togglePause: return String(localized: "Toggle pause", comment: "Keyboard shortcut row title")
    case .skipBreak: return String(localized: "Skip current break", comment: "Keyboard shortcut row title")
    }
  }
}
