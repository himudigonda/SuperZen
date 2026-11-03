import Foundation

enum SettingsSections {
  static let exemptKeys: Set<String> = [
    SettingKey.hasCompletedOnboarding,
    SettingKey.launchAtLogin,
    SettingKey.wellnessCadenceVersion,
  ]

  static func keys(for section: PreferencesSection) -> [String] {
    switch section {
    case .general:
      return [
        SettingKey.menuBarDisplay, SettingKey.timerStyle,
        SettingKey.focusScheduleEnabled, SettingKey.focusScheduleStartMinute,
        SettingKey.focusScheduleEndMinute, SettingKey.focusScheduleWeekdays,
        SettingKey.focusScheduleAutoResume,
        SettingKey.dayProgressEnabled, SettingKey.dayProgressStartMinute,
        SettingKey.dayProgressEndMinute, SettingKey.dayProgressBarStyle,
        SettingKey.dayProgressMetric, SettingKey.dayProgressFills,
        SettingKey.dailyFocusGoalMinutes, SettingKey.dailyBreakGoalCount,
        SettingKey.dailyWellnessGoalCount, SettingKey.insightsShowGoalLine,
        SettingKey.insightScoringProfile, SettingKey.insightsForecastEnabled,
      ]
    case .breakSchedule:
      return [
        SettingKey.workDuration, SettingKey.breakDuration, SettingKey.nudgeLeadTime,
        SettingKey.longBreakDuration, SettingKey.longBreakEvery, SettingKey.difficulty,
        SettingKey.dontShowWhileTyping, SettingKey.typingDeferralCap,
        SettingKey.forceResetFocusAfterBreak, SettingKey.plannedBreaks, SettingKey.maxPostpones,
        SettingKey.deferralApps, SettingKey.deferralCap, SettingKey.deferralDuringCalls,
        SettingKey.deferralDuringFullscreen,
      ]
    case .wellnessReminders:
      return [
        SettingKey.postureEnabled, SettingKey.postureFrequency,
        SettingKey.blinkEnabled, SettingKey.blinkFrequency,
        SettingKey.waterEnabled, SettingKey.waterFrequency,
        SettingKey.affirmationEnabled, SettingKey.affirmationFrequency,
        SettingKey.dimScreenWellness, SettingKey.focusIdleThreshold,
        SettingKey.interruptionThreshold, SettingKey.wellnessDurationMultiplier,
        SettingKey.quietHoursEnabled, SettingKey.quietHoursStartMinute,
        SettingKey.quietHoursEndMinute,
      ]
    case .appearance:
      return [
        SettingKey.breakBackground, SettingKey.blurBackground, SettingKey.customImagePath,
        SettingKey.alertPosition, SettingKey.reminderEnabled, SettingKey.reminderDuration,
        SettingKey.uiAccentPalette, SettingKey.uiContrastProfile, SettingKey.breakTipsEnabled,
      ]
    case .soundEffects:
      return [
        SettingKey.soundVolume, SettingKey.soundBreakStart, SettingKey.soundBreakEnd,
        SettingKey.soundNudge,
      ]
    case .keyboardShortcuts:
      return [SettingKey.shortcutStartBreak, SettingKey.shortcutTogglePause, SettingKey.shortcutSkipBreak]
    case .advanced:
      return [
        SettingKey.balancedSkipLockRatio, SettingKey.dataRetentionEnabled,
        SettingKey.dataRetentionDays, SettingKey.appUsageTrackingEnabled,
      ]
    case .about, .insights:
      return []
    }
  }

  static func reset(_ section: PreferencesSection, in defaults: UserDefaults = .standard) {
    for key in keys(for: section) where !exemptKeys.contains(key) {
      defaults.removeObject(forKey: key)
    }
  }
}

extension PreferencesSection {
  var settingKeys: [String] { SettingsSections.keys(for: self) }
}
