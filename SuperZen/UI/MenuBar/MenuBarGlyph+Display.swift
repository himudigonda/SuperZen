import Foundation
import SuperZenCore

extension MenuBarGlyph {
  var symbolName: String {
    switch self {
    case .focusing: return "eye.circle.fill"
    case .away: return "moon.circle.fill"
    case .breakSoon: return "hourglass"
    case .typing: return "keyboard.fill"
    case .shortBreak: return "eye.slash.fill"
    case .longBreak: return "figure.walk"
    case .wellness: return "figure.mind.and.body"
    case .paused: return "pause.circle.fill"
    case .scheduleSleep: return "moon.zzz.fill"
    }
  }

  var title: String {
    switch self {
    case .focusing: return String(localized: "Focusing", comment: "Menu bar status")
    case .away: return String(localized: "Away", comment: "Menu bar status while the user has stepped away")
    case .breakSoon: return String(localized: "Break soon", comment: "Menu bar status")
    case .typing: return String(localized: "Waiting for a pause in typing", comment: "Menu bar status")
    case .shortBreak: return String(localized: "Eye break", comment: "Menu bar status")
    case .longBreak: return String(localized: "Long break", comment: "Menu bar status")
    case .wellness: return String(localized: "Wellness moment", comment: "Menu bar status")
    case .paused: return String(localized: "Paused", comment: "Menu bar status")
    case .scheduleSleep: return String(localized: "Outside focus hours", comment: "Menu bar status")
    }
  }

  var compactLabel: String? {
    switch self {
    case .away: return String(localized: "Away", comment: "Menu bar status while the user has stepped away")
    case .typing: return String(localized: "Typing", comment: "Compact menu bar label while typing")
    case .paused: return String(localized: "Paused", comment: "Compact menu bar label while paused")
    case .scheduleSleep:
      return String(localized: "Sleeping", comment: "Compact menu bar label while sleeping on schedule")
    case .focusing, .breakSoon, .shortBreak, .longBreak, .wellness: return nil
    }
  }

  var ringCaption: String {
    switch self {
    case .focusing, .breakSoon, .wellness:
      return String(localized: "until break", comment: "Menu bar popover ring caption")
    case .away:
      return String(localized: "when you return", comment: "Menu bar popover ring caption while away")
    case .shortBreak, .longBreak:
      return String(localized: "left to rest", comment: "Menu bar popover ring caption")
    case .paused, .typing:
      return String(localized: "on hold", comment: "Menu bar popover ring caption")
    case .scheduleSleep:
      return String(localized: "off hours", comment: "Menu bar popover ring caption")
    }
  }
}

extension BreakKind {
  var title: String {
    switch self {
    case .short: return String(localized: "Eye break", comment: "Break kind name")
    case .long: return String(localized: "Long break", comment: "Break kind name")
    }
  }
}
