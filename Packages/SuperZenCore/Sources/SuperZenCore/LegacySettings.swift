import Foundation

public enum LegacyKey: String, CaseIterable, Sendable {
  case workDuration
  case breakDuration
  case longBreakDuration
  case longBreakEvery
  case typingDeferralCap
  case difficulty
  case nudgeLeadTime
  case dontShowWhileTyping
  case postureEnabled
  case postureFrequency
  case blinkEnabled
  case blinkFrequency
  case waterEnabled
  case waterFrequency
  case affirmationEnabled
  case affirmationFrequency
  case focusIdleThreshold
  case focusScheduleEnabled
  case focusScheduleStartMinute
  case focusScheduleEndMinute
  case focusScheduleWeekdays
  case focusScheduleAutoResume
  case quietHoursEnabled
  case quietHoursStartMinute
  case quietHoursEndMinute
  case forceResetFocusAfterBreak
  case balancedSkipLockRatio
  case wellnessDurationMultiplier
}

public enum LegacySettingsMigration {
  public static func migrate(_ lookup: @escaping (String) -> Any?) -> Settings {
    read(lookup).validated()
  }

  public static func read(_ lookup: @escaping (String) -> Any?) -> Settings {
    let reader = Reader(lookup: lookup)
    var settings = Settings()

    reader.double(.workDuration).map { settings.timer.workDuration = $0 }
    reader.double(.breakDuration).map { settings.timer.shortBreakDuration = $0 }
    reader.double(.longBreakDuration).map { settings.timer.longBreakDuration = $0 }
    reader.int(.longBreakEvery).map { settings.timer.longBreakEvery = $0 }
    reader.double(.typingDeferralCap).map { settings.timer.typingDeferralCap = $0 }
    reader.double(.nudgeLeadTime).map { settings.timer.nudgeLeadTime = $0 }
    reader.bool(.dontShowWhileTyping).map { settings.timer.deferWhileTyping = $0 }
    reader.double(.focusIdleThreshold).map { settings.timer.idleThreshold = $0 }
    reader.bool(.forceResetFocusAfterBreak).map { settings.timer.resetFocusAfterBreak = $0 }

    reader.string(.difficulty).flatMap(BreakDifficulty.init(rawValue:)).map {
      settings.skipPolicy.difficulty = $0
    }
    reader.double(.balancedSkipLockRatio).map { settings.skipPolicy.balancedLockRatio = $0 }

    let reminderKeys: [(WellnessKind, LegacyKey, LegacyKey)] = [
      (.posture, .postureEnabled, .postureFrequency),
      (.blink, .blinkEnabled, .blinkFrequency),
      (.water, .waterEnabled, .waterFrequency),
      (.affirmation, .affirmationEnabled, .affirmationFrequency),
    ]
    for (kind, enabledKey, intervalKey) in reminderKeys {
      reader.bool(enabledKey).map { settings.wellness[kind].enabled = $0 }
      reader.double(intervalKey).map { settings.wellness[kind].interval = $0 }
    }
    reader.double(.wellnessDurationMultiplier).map { settings.wellness.durationMultiplier = $0 }

    reader.bool(.focusScheduleEnabled).map { settings.schedule.enabled = $0 }
    settings.schedule.window = TimeWindow(
      startMinute: reader.int(.focusScheduleStartMinute) ?? settings.schedule.window.startMinute,
      endMinute: reader.int(.focusScheduleEndMinute) ?? settings.schedule.window.endMinute)
    reader.string(.focusScheduleWeekdays).map { settings.schedule.weekdays = SchedulePolicy.weekdaySet(from: $0) }
    reader.bool(.focusScheduleAutoResume).map { settings.schedule.autoResume = $0 }

    reader.bool(.quietHoursEnabled).map { settings.quietHours.enabled = $0 }
    settings.quietHours.window = TimeWindow(
      startMinute: reader.int(.quietHoursStartMinute) ?? settings.quietHours.window.startMinute,
      endMinute: reader.int(.quietHoursEndMinute) ?? settings.quietHours.window.endMinute)

    return settings
  }

  private struct Reader {
    let lookup: (String) -> Any?

    func double(_ key: LegacyKey) -> Double? {
      switch lookup(key.rawValue) {
      case let value as Double: return value
      case let value as Int: return Double(value)
      case let value as String: return Double(value)
      default: return nil
      }
    }

    func int(_ key: LegacyKey) -> Int? {
      switch lookup(key.rawValue) {
      case let value as Int: return value
      case let value as Double where value.isFinite: return Int(value)
      case let value as String: return Int(value)
      default: return nil
      }
    }

    func bool(_ key: LegacyKey) -> Bool? {
      switch lookup(key.rawValue) {
      case let value as Bool: return value
      case let value as Int: return value != 0
      case let value as String: return Bool(value)
      default: return nil
      }
    }

    func string(_ key: LegacyKey) -> String? {
      lookup(key.rawValue) as? String
    }
  }
}
