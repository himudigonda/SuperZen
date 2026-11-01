import Foundation
import SuperZenCore

enum SettingsValidation {
  static func issues(in defaults: UserDefaults) -> [SettingsIssue] {
    LegacySettingsMigration.read { defaults.object(forKey: $0) }.issues
  }
}

extension SettingsIssue {
  var message: String {
    switch self {
    case .reminderNotShorterThanWork:
      return String(
        localized: "The heads-up comes before the break starts, so it must be shorter than the focus block.",
        comment: "Settings validation message")
    case .longBreakNotLongerThanShort:
      return String(
        localized: "Long breaks should be longer than regular breaks. Pick a longer length or turn long breaks off.",
        comment: "Settings validation message")
    case .scheduleHasNoWeekdays:
      return String(
        localized: "Pick at least one weekday, or SuperZen will stay asleep all week.",
        comment: "Settings validation message")
    }
  }

  var section: SettingsSectionScope {
    switch self {
    case .reminderNotShorterThanWork, .longBreakNotLongerThanShort: return .breakSchedule
    case .scheduleHasNoWeekdays: return .general
    }
  }
}

enum SettingsSectionScope: Sendable {
  case general
  case breakSchedule
}
