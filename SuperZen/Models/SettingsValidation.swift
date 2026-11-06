import Foundation
import SuperZenCore

enum SettingsValidation {
  static func issues(in defaults: UserDefaults) -> [SettingsIssue] {
    let settings = LegacySettingsMigration.read { defaults.object(forKey: $0) }
    let presentation = BreakPresentation(setting: defaults.string(forKey: SettingKey.breakPresentation))
    return settings.issues + (presentation.issue(for: settings.skipPolicy.difficulty).map { [$0] } ?? [])
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
    case .bannerUnavailableInHardcore:
      return String(
        localized: "Hardcore breaks always use the full screen, so the banner style is ignored.",
        comment: "Settings validation message when the banner break style is chosen with hardcore difficulty")
    }
  }

  var section: SettingsSectionScope {
    switch self {
    case .reminderNotShorterThanWork, .longBreakNotLongerThanShort: return .breakSchedule
    case .scheduleHasNoWeekdays: return .general
    case .bannerUnavailableInHardcore: return .appearance
    }
  }
}

enum SettingsSectionScope: Sendable {
  case general
  case breakSchedule
  case appearance
}
