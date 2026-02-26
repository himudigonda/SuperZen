import Foundation

enum BreakDifficulty: String, CaseIterable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"
  var id: String { rawValue }
}

enum SettingKey {
  static let workDuration = "workDuration"
  static let breakDuration = "breakDuration"
  static let difficulty = "difficulty"
  static let nudgeLeadTime = "nudgeLeadTime"
  static let dontShowWhileTyping = "dontShowWhileTyping"
  static let launchAtLogin = "launchAtLogin"
  static let menuBarDisplay = "menuBarDisplay"
  static let timerStyle = "timerStyle"
  static let postureEnabled = "postureEnabled"
  static let postureFrequency = "postureFrequency"
  static let blinkEnabled = "blinkEnabled"
  static let blinkFrequency = "blinkFrequency"
  static let waterEnabled = "waterEnabled"
  static let waterFrequency = "waterFrequency"
  static let affirmationEnabled = "affirmationEnabled"
  static let affirmationFrequency = "affirmationFrequency"
  static let focusIdleThreshold = "focusIdleThreshold"
  static let interruptionThreshold = "interruptionThreshold"
  static let insightScoringProfile = "insightScoringProfile"
  static let breakBackground = "breakBackground"  // "Wallpaper" | "Gradient" | "Custom"
  static let blurBackground = "blurBackground"
  static let customImagePath = "customImagePath"
  static let alertPosition = "alertPosition"  // "left" | "center" | "right"
  static let reminderEnabled = "reminderEnabled"
  static let reminderDuration = "reminderDuration"
  static let soundVolume = "masterVolume"  // key stays "masterVolume" for back-compat
  static let soundBreakStart = "soundBreakStart"
  static let soundBreakEnd = "soundBreakEnd"
  static let soundNudge = "soundNudge"
  static let focusScheduleEnabled = "focusScheduleEnabled"
  static let focusScheduleStartMinute = "focusScheduleStartMinute"
  static let focusScheduleEndMinute = "focusScheduleEndMinute"
  static let focusScheduleWeekdays = "focusScheduleWeekdays"  // CSV 1...7 (Sun...Sat)
  static let focusScheduleAutoResume = "focusScheduleAutoResume"
  static let quietHoursEnabled = "quietHoursEnabled"
  static let quietHoursStartMinute = "quietHoursStartMinute"
  static let quietHoursEndMinute = "quietHoursEndMinute"
  static let nudgeSnoozeEnabled = "nudgeSnoozeEnabled"
  static let nudgeSnoozeDuration = "nudgeSnoozeDuration"
  static let dailyFocusGoalMinutes = "dailyFocusGoalMinutes"
  static let dailyBreakGoalCount = "dailyBreakGoalCount"
  static let dailyWellnessGoalCount = "dailyWellnessGoalCount"
  static let insightsShowGoalLine = "insightsShowGoalLine"

  /// Call once at app launch so UserDefaults always has sane values even before
  /// the user has opened Settings for the first time.
  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      workDuration: 1500.0,
      breakDuration: 300.0,
      nudgeLeadTime: 10.0,
      dontShowWhileTyping: true,
      postureEnabled: true,
      postureFrequency: 1200.0,
      blinkEnabled: true,
      blinkFrequency: 1200.0,
      waterEnabled: true,
      waterFrequency: 3600.0,
      affirmationEnabled: true,
      affirmationFrequency: 3600.0,
      focusIdleThreshold: 20.0,
      interruptionThreshold: 30.0,
      insightScoringProfile: "Balanced",
      breakBackground: "Wallpaper",
      blurBackground: true,
      alertPosition: "center",
      reminderEnabled: true,
      reminderDuration: 10.0,
      soundVolume: 0.8,
      soundBreakStart: "Hero",
      soundBreakEnd: "Glass",
      soundNudge: "Pop",
      focusScheduleEnabled: false,
      focusScheduleStartMinute: 540,  // 9:00 AM
      focusScheduleEndMinute: 1080,  // 6:00 PM
      focusScheduleWeekdays: "2,3,4,5,6",  // Monday-Friday
      focusScheduleAutoResume: true,
      quietHoursEnabled: false,
      quietHoursStartMinute: 1320,  // 10:00 PM
      quietHoursEndMinute: 420,  // 7:00 AM
      nudgeSnoozeEnabled: true,
      nudgeSnoozeDuration: 300.0,
      dailyFocusGoalMinutes: 240,
      dailyBreakGoalCount: 6,
      dailyWellnessGoalCount: 8,
      insightsShowGoalLine: true,
      "shortcutStartBreak": "⌃⌥⌘B",
      "shortcutTogglePause": "⌃⌥⌘P",
      "shortcutSkipBreak": "⌃⌥⌘S",
    ])
  }
}
