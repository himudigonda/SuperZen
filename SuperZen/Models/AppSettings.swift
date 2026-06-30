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
  static let dimScreenWellness = "dimScreenWellness"
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
  static let dayProgressEnabled = "dayProgressEnabled"
  static let dayProgressStartMinute = "dayProgressStartMinute"
  static let dayProgressEndMinute = "dayProgressEndMinute"
  static let dayProgressBarStyle = "dayProgressBarStyle"
  // "bar_label" | "bar_only" | "label_only" | "bar_label_inside"
  static let dayProgressMetric = "dayProgressMetric"
  // "pct_done" | "pct_remaining" | "min_elapsed" | "min_remaining"
  // | "hr_elapsed" | "hr_remaining" | "hr_min_elapsed" | "hr_min_remaining"
  static let dayProgressFills = "dayProgressFills"  // true = fills left→right, false = depletes
  static let quietHoursEnabled = "quietHoursEnabled"
  static let quietHoursStartMinute = "quietHoursStartMinute"
  static let quietHoursEndMinute = "quietHoursEndMinute"
  static let dailyFocusGoalMinutes = "dailyFocusGoalMinutes"
  static let dailyBreakGoalCount = "dailyBreakGoalCount"
  static let dailyWellnessGoalCount = "dailyWellnessGoalCount"
  static let insightsShowGoalLine = "insightsShowGoalLine"
  static let uiAccentPalette = "uiAccentPalette"
  static let uiContrastProfile = "uiContrastProfile"
  static let forceResetFocusAfterBreak = "forceResetFocusAfterBreak"
  static let balancedSkipLockRatio = "balancedSkipLockRatio"
  static let wellnessDurationMultiplier = "wellnessDurationMultiplier"
  static let dataRetentionEnabled = "dataRetentionEnabled"
  static let dataRetentionDays = "dataRetentionDays"
  static let insightsForecastEnabled = "insightsForecastEnabled"
  static let shortcutStartBreak = "shortcutStartBreak"
  static let shortcutTogglePause = "shortcutTogglePause"
  static let shortcutSkipBreak = "shortcutSkipBreak"
  static let hasCompletedOnboarding = "hasCompletedOnboarding"

  /// Call once at app launch so UserDefaults always has sane values even before
  /// the user has opened Settings for the first time.
  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      workDuration: 1500.0,
      breakDuration: 300.0,
      difficulty: BreakDifficulty.balanced.rawValue,
      nudgeLeadTime: 10.0,
      dontShowWhileTyping: true,
      launchAtLogin: false,
      menuBarDisplay: "Icon and text",
      timerStyle: "15:11",
      postureEnabled: true,
      postureFrequency: 1200.0,
      blinkEnabled: true,
      blinkFrequency: 1200.0,
      dimScreenWellness: true,
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
      dayProgressEnabled: false,
      dayProgressStartMinute: 540,  // 9:00 AM
      dayProgressEndMinute: 1080,  // 6:00 PM
      dayProgressBarStyle: "bar_label",
      dayProgressMetric: "pct_done",
      dayProgressFills: true,
      quietHoursEnabled: false,
      quietHoursStartMinute: 1320,  // 10:00 PM
      quietHoursEndMinute: 420,  // 7:00 AM
      dailyFocusGoalMinutes: 240,
      dailyBreakGoalCount: 6,
      dailyWellnessGoalCount: 8,
      insightsShowGoalLine: true,
      uiAccentPalette: "Ocean",
      uiContrastProfile: "Balanced",
      forceResetFocusAfterBreak: true,
      balancedSkipLockRatio: 0.5,
      wellnessDurationMultiplier: 1.0,
      dataRetentionEnabled: true,
      dataRetentionDays: 90,
      insightsForecastEnabled: true,
      shortcutStartBreak: "⌃⌥⌘B",
      shortcutTogglePause: "⌃⌥⌘P",
      shortcutSkipBreak: "⌃⌥⌘S",
      hasCompletedOnboarding: false,
    ])
  }
}

enum SettingsCatalog {
  static let workDurationOptions: [(String, Double)] = [
    ("20 minutes", 1200),
    ("25 minutes", 1500),
    ("30 minutes", 1800),
    ("45 minutes", 2700),
    ("60 minutes", 3600),
    ("90 minutes", 5400),
  ]

  static let breakDurationOptions: [(String, Double)] = [
    ("20 seconds", 20),
    ("1 minute", 60),
    ("5 minutes", 300),
    ("10 minutes", 600),
  ]

  static let reminderLeadTimeOptions: [(String, Double)] = [
    ("10 seconds", 10),
    ("30 seconds", 30),
    ("1 minute", 60),
  ]

  static let commonWellnessFrequencyOptions: [(String, Double)] = [
    ("10 minutes", 600),
    ("20 minutes", 1200),
    ("30 minutes", 1800),
    ("45 minutes", 2700),
    ("1 hour", 3600),
  ]

  static let affirmationFrequencyOptions: [(String, Double)] = [
    ("15 minutes", 900),
    ("30 minutes", 1800),
    ("1 hour", 3600),
    ("2 hours", 7200),
  ]

  static let accentPalettes = ["Ocean", "Emerald", "Sunset", "Violet", "Mono"]
  static let contrastProfiles = ["Soft", "Balanced", "High"]
  static let scoringProfiles = ["Balanced", "Deep Focus", "Recovery"]

  static let balancedSkipLockOptions: [(String, Double)] = [
    ("20% of break", 0.2),
    ("35% of break", 0.35),
    ("50% of break", 0.5),
    ("65% of break", 0.65),
    ("80% of break", 0.8),
  ]

  static let wellnessDurationMultiplierOptions: [(String, Double)] = [
    ("0.25x", 0.25),
    ("0.5x", 0.5),
    ("0.75x", 0.75),
    ("1.0x", 1.0),
    ("1.5x", 1.5),
    ("2.0x", 2.0),
  ]

  static let retentionDaysOptions = [7, 14, 30, 60, 90, 180, 365]

  static let dayProgressBarStyles: [(String, String)] = [
    ("Bar + Label", "bar_label"),
    ("Bar only", "bar_only"),
    ("Label only", "label_only"),
    ("Label inside bar", "bar_label_inside"),
  ]

  static let dayProgressMetrics: [(String, String)] = [
    ("% done", "pct_done"),
    ("% remaining", "pct_remaining"),
    ("Minutes elapsed", "min_elapsed"),
    ("Minutes left", "min_remaining"),
    ("Hours elapsed", "hr_elapsed"),
    ("Hours left", "hr_remaining"),
    ("Time elapsed", "hr_min_elapsed"),
    ("Time left", "hr_min_remaining"),
  ]

  static let dayProgressFillsOptions: [(String, Bool)] = [
    ("Fills →", true),
    ("Depletes ←", false),
  ]
}
