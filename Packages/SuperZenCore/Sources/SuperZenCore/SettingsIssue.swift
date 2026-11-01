import Foundation

public enum SettingsIssue: String, CaseIterable, Sendable {
  case reminderNotShorterThanWork
  case longBreakNotLongerThanShort
  case scheduleHasNoWeekdays
}

extension Settings {
  public var issues: [SettingsIssue] {
    var found: [SettingsIssue] = []
    if timer.nudgeLeadTime >= timer.workDuration { found.append(.reminderNotShorterThanWork) }
    if timer.longBreakEvery > 0 && timer.longBreakDuration <= timer.shortBreakDuration {
      found.append(.longBreakNotLongerThanShort)
    }
    if schedule.enabled && schedule.weekdays.isEmpty { found.append(.scheduleHasNoWeekdays) }
    return found
  }
}
