import Foundation

enum BreakDifficulty: String, CaseIterable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"
  var id: String { rawValue }

  /// Localized label for display. `rawValue` stays the stable English token used for
  /// `@AppStorage` persistence and comparisons — never localize it in place.
  var displayName: String {
    switch self {
    case .casual: return String(localized: "Casual", comment: "Break skip difficulty: casual")
    case .balanced: return String(localized: "Balanced", comment: "Break skip difficulty: balanced")
    case .hardcore: return String(localized: "Hardcore", comment: "Break skip difficulty: hardcore")
    }
  }
}

/// Every UserDefaults key SuperZen persists, as raw strings. This is the ONLY place a
/// settings key literal should be written — everywhere else in the app references
/// `SettingKey.x`, never the raw string, so a rename can't silently create two keys.
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
  static let breakBackground = "breakBackground"  // one of SettingsCatalog.breakBackgroundOptions
  static let blurBackground = "blurBackground"
  static let customImagePath = "customImagePath"
  static let alertPosition = "alertPosition"  // one of SettingsCatalog.alertPositionOptions
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
  static let dayProgressMetric = "dayProgressMetric"
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

  /// Every settings key above, in one place. Used by the test suite to snapshot and
  /// restore the real UserDefaults domain around each test (the test target's TEST_HOST
  /// is SuperZen.app itself, so tests run against the same UserDefaults a real user has).
  /// Keep this in sync when adding a new key.
  static let allKeys: [String] = [
    workDuration, breakDuration, difficulty, nudgeLeadTime, dontShowWhileTyping,
    launchAtLogin, menuBarDisplay, timerStyle, postureEnabled, postureFrequency,
    blinkEnabled, blinkFrequency, dimScreenWellness, waterEnabled, waterFrequency,
    affirmationEnabled, affirmationFrequency, focusIdleThreshold, interruptionThreshold,
    insightScoringProfile, breakBackground, blurBackground, customImagePath, alertPosition,
    reminderEnabled, reminderDuration, soundVolume, soundBreakStart, soundBreakEnd,
    soundNudge, focusScheduleEnabled, focusScheduleStartMinute, focusScheduleEndMinute,
    focusScheduleWeekdays, focusScheduleAutoResume, dayProgressEnabled,
    dayProgressStartMinute, dayProgressEndMinute, dayProgressBarStyle, dayProgressMetric,
    dayProgressFills, quietHoursEnabled, quietHoursStartMinute, quietHoursEndMinute,
    dailyFocusGoalMinutes, dailyBreakGoalCount, dailyWellnessGoalCount,
    insightsShowGoalLine, uiAccentPalette, uiContrastProfile, forceResetFocusAfterBreak,
    balancedSkipLockRatio, wellnessDurationMultiplier, dataRetentionEnabled,
    dataRetentionDays, insightsForecastEnabled, shortcutStartBreak, shortcutTogglePause,
    shortcutSkipBreak, hasCompletedOnboarding,
  ]

  /// Call once at app launch so UserDefaults always has sane values even before
  /// the user has opened Settings for the first time. Every value below is sourced from
  /// `SettingsCatalog` — this function must never contain a literal that isn't also the
  /// literal backing a `SettingsCatalog.xDefault`/`xOptions` entry.
  static func registerDefaults(in defaults: UserDefaults = .standard) {
    defaults.register(defaults: [
      workDuration: SettingsCatalog.workDurationDefault,
      breakDuration: SettingsCatalog.breakDurationDefault,
      difficulty: BreakDifficulty.balanced.rawValue,
      nudgeLeadTime: SettingsCatalog.nudgeLeadTimeDefault,
      dontShowWhileTyping: true,
      launchAtLogin: false,
      menuBarDisplay: SettingsCatalog.menuBarDisplayDefault,
      timerStyle: SettingsCatalog.timerStyleDefault,
      postureEnabled: true,
      postureFrequency: SettingsCatalog.shortWellnessFrequencyDefault,
      blinkEnabled: true,
      blinkFrequency: SettingsCatalog.shortWellnessFrequencyDefault,
      dimScreenWellness: true,
      waterEnabled: true,
      waterFrequency: SettingsCatalog.longWellnessFrequencyDefault,
      affirmationEnabled: true,
      affirmationFrequency: SettingsCatalog.longWellnessFrequencyDefault,
      focusIdleThreshold: SettingsCatalog.idleThresholdDefault,
      interruptionThreshold: SettingsCatalog.interruptionThresholdDefault,
      insightScoringProfile: SettingsCatalog.scoringProfileDefault,
      breakBackground: SettingsCatalog.breakBackgroundDefault,
      blurBackground: true,
      customImagePath: "",
      alertPosition: SettingsCatalog.alertPositionDefault,
      reminderEnabled: true,
      reminderDuration: SettingsCatalog.reminderDurationDefault,
      soundVolume: 0.8,
      soundBreakStart: SettingsCatalog.soundBreakStartDefault,
      soundBreakEnd: SettingsCatalog.soundBreakEndDefault,
      soundNudge: SettingsCatalog.soundNudgeDefault,
      focusScheduleEnabled: false,
      focusScheduleStartMinute: SettingsCatalog.defaultWorkdayStartMinute,
      focusScheduleEndMinute: SettingsCatalog.defaultWorkdayEndMinute,
      focusScheduleWeekdays: SettingsCatalog.defaultWeekdaysCSV,
      focusScheduleAutoResume: true,
      dayProgressEnabled: false,
      dayProgressStartMinute: SettingsCatalog.defaultWorkdayStartMinute,
      dayProgressEndMinute: SettingsCatalog.defaultWorkdayEndMinute,
      dayProgressBarStyle: SettingsCatalog.dayProgressBarStyleDefault,
      dayProgressMetric: SettingsCatalog.dayProgressMetricDefault,
      dayProgressFills: true,
      quietHoursEnabled: false,
      quietHoursStartMinute: SettingsCatalog.defaultQuietHoursStartMinute,
      quietHoursEndMinute: SettingsCatalog.defaultQuietHoursEndMinute,
      dailyFocusGoalMinutes: SettingsCatalog.dailyFocusGoalDefault,
      dailyBreakGoalCount: SettingsCatalog.dailyBreakGoalDefault,
      dailyWellnessGoalCount: SettingsCatalog.dailyWellnessGoalDefault,
      insightsShowGoalLine: true,
      uiAccentPalette: SettingsCatalog.accentPaletteDefault,
      uiContrastProfile: SettingsCatalog.contrastProfileDefault,
      forceResetFocusAfterBreak: true,
      balancedSkipLockRatio: SettingsCatalog.balancedSkipLockRatioDefault,
      wellnessDurationMultiplier: SettingsCatalog.wellnessDurationMultiplierDefault,
      dataRetentionEnabled: true,
      dataRetentionDays: SettingsCatalog.dataRetentionDaysDefault,
      insightsForecastEnabled: true,
      shortcutStartBreak: SettingsCatalog.shortcutStartBreakDefault,
      shortcutTogglePause: SettingsCatalog.shortcutTogglePauseDefault,
      shortcutSkipBreak: SettingsCatalog.shortcutSkipBreakDefault,
      hasCompletedOnboarding: false,
    ])
  }
}

/// The single source of truth for every default value, selectable option list, clamp range,
/// and display-name mapping in SuperZen. Nothing outside this file should ever type a
/// settings-related literal (a duration, a token string, an option list) a second time —
/// reference the constant here instead, so changing a default only ever requires one edit.
nonisolated enum SettingsCatalog {

  // MARK: - Work / break timing

  static let workDurationDefault: Double = 1500  // 25 minutes
  static let workDurationOptions: [(String, Double)] = [
    ("20 minutes", 1200),
    ("25 minutes", 1500),
    ("30 minutes", 1800),
    ("45 minutes", 2700),
    ("60 minutes", 3600),
    ("90 minutes", 5400),
  ]

  static let breakDurationDefault: Double = 300  // 5 minutes
  static let breakDurationOptions: [(String, Double)] = [
    ("20 seconds", 20),
    ("1 minute", 60),
    ("5 minutes", 300),
    ("10 minutes", 600),
  ]

  static let nudgeLeadTimeDefault: Double = 10
  static let reminderLeadTimeOptions: [(String, Double)] = [
    ("10 seconds", 10),
    ("30 seconds", 30),
    ("1 minute", 60),
  ]

  static let reminderDurationDefault: Double = 10
  static let reminderDurationOptions: [(String, Double)] = [
    ("5 seconds", 5),
    ("10 seconds", 10),
    ("15 seconds", 15),
    ("20 seconds", 20),
  ]

  /// Balanced-mode skip lock never makes the user wait longer than this, regardless of
  /// how long the configured break is or what `balancedSkipLockRatio` computes to.
  static let maxSkipLockSeconds: Double = 20
  static let balancedSkipLockRatioDefault: Double = 0.5
  /// Runtime clamp is intentionally wider than `balancedSkipLockOptions` (which is what the
  /// UI offers) so a value written outside the UI's own range still behaves sanely.
  static let balancedSkipLockRatioClamp: ClosedRange<Double> = 0.1...0.9
  static let balancedSkipLockOptions: [(String, Double)] = [
    ("20% of break", 0.2),
    ("35% of break", 0.35),
    ("50% of break", 0.5),
    ("65% of break", 0.65),
    ("80% of break", 0.8),
  ]

  static let defaultSnoozeDuration: TimeInterval = 300  // 5 minutes

  // MARK: - Wellness reminders

  /// Posture/blink default cadence — short, frequent nudges.
  static let shortWellnessFrequencyDefault: Double = 1200  // 20 minutes
  /// Water/affirmation default cadence — longer, less frequent nudges.
  static let longWellnessFrequencyDefault: Double = 3600  // 1 hour
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

  static let wellnessDurationMultiplierDefault: Double = 1.0
  static let wellnessDurationMultiplierClamp: ClosedRange<Double> = 0.1...2.0
  static let wellnessDurationMultiplierOptions: [(String, Double)] = [
    ("0.25x", 0.25),
    ("0.5x", 0.5),
    ("0.75x", 0.75),
    ("1.0x", 1.0),
    ("1.5x", 1.5),
    ("2.0x", 2.0),
  ]

  // MARK: - Focus telemetry

  static let idleThresholdDefault: Double = 20
  static let idleThresholdOptions: [(String, Double)] = [
    ("10 seconds", 10),
    ("20 seconds", 20),
    ("30 seconds", 30),
    ("1 minute", 60),
  ]

  static let interruptionThresholdDefault: Double = 30
  static let interruptionThresholdOptions: [(String, Double)] = [
    ("20 seconds", 20),
    ("30 seconds", 30),
    ("45 seconds", 45),
    ("1 minute", 60),
  ]

  // MARK: - Schedules & windows

  static let defaultWorkdayStartMinute = 540  // 9:00 AM
  static let defaultWorkdayEndMinute = 1080  // 6:00 PM
  static let defaultWeekdaysCSV = "2,3,4,5,6"  // Monday-Friday

  static let defaultQuietHoursStartMinute = 1320  // 10:00 PM
  static let defaultQuietHoursEndMinute = 420  // 7:00 AM

  // MARK: - Daily goals

  static let dailyFocusGoalDefault = 240
  static let dailyFocusGoalOptions = [90, 120, 180, 240, 300, 360]
  static let dailyBreakGoalDefault = 6
  static let dailyBreakGoalOptions = [2, 4, 6, 8, 10, 12]
  static let dailyWellnessGoalDefault = 8
  static let dailyWellnessGoalOptions = [2, 4, 6, 8, 10, 12]

  // MARK: - Data retention

  static let dataRetentionDaysDefault = 90
  static let retentionDaysOptions = [7, 14, 30, 60, 90, 180, 365]

  // MARK: - Appearance

  static let accentPaletteDefault = "Ocean"
  static let accentPalettes = ["Ocean", "Emerald", "Sunset", "Violet", "Mono"]

  static let contrastProfileDefault = "Balanced"
  static let contrastProfiles = ["Soft", "Balanced", "High"]

  static let scoringProfileDefault = "Balanced"
  static let scoringProfiles = ["Balanced", "Deep Focus", "Recovery"]

  static let menuBarDisplayDefault = "Icon and text"
  static let menuBarDisplayOptions = ["Icon and text", "Icon only", "Text only"]

  /// Each token is also its own display label — it's a live example of the format, not a
  /// name that needs translating.
  static let timerStyleDefault = "15:11"
  static let timerStyleOptions = ["15:11", "15m", "15"]

  static let breakBackgroundDefault = "Wallpaper"
  static let breakBackgroundOptions = ["Wallpaper", "Gradient", "Custom"]

  static let alertPositionDefault = "center"
  static let alertPositionOptions = ["left", "center", "right"]

  static let dayProgressBarStyleDefault = "bar_label"
  static let dayProgressBarStyles: [(String, String)] = [
    ("Bar + Label", "bar_label"),
    ("Bar only", "bar_only"),
    ("Label only", "label_only"),
    ("Label inside bar", "bar_label_inside"),
  ]

  static let dayProgressMetricDefault = "pct_done"
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

  // MARK: - Sounds
  // The catalog of available sound *names* (system sound assets) lives in
  // `SoundManager.availableSounds` — that subsystem owns which sounds physically exist.
  // Only the per-event defaults are settings, so only the defaults live here.

  static let soundBreakStartDefault = "Hero"
  static let soundBreakEndDefault = "Glass"
  static let soundNudgeDefault = "Pop"

  // MARK: - Keyboard shortcuts

  static let shortcutStartBreakDefault = "⌃⌥⌘B"
  static let shortcutTogglePauseDefault = "⌃⌥⌘P"
  static let shortcutSkipBreakDefault = "⌃⌥⌘S"

  // MARK: - Display-name mappers
  // Localized label for a stable token. The token itself (e.g. "Ocean") stays the stable,
  // persisted/compared value — never localize it in place.

  static func accentPaletteDisplayName(_ palette: String) -> String {
    switch palette {
    case "Emerald": return String(localized: "Emerald", comment: "Accent color palette name")
    case "Sunset": return String(localized: "Sunset", comment: "Accent color palette name")
    case "Violet": return String(localized: "Violet", comment: "Accent color palette name")
    case "Mono": return String(localized: "Mono", comment: "Accent color palette name")
    default: return String(localized: "Ocean", comment: "Accent color palette name")
    }
  }

  static func contrastProfileDisplayName(_ profile: String) -> String {
    switch profile {
    case "Soft": return String(localized: "Soft", comment: "UI contrast profile name")
    case "High": return String(localized: "High", comment: "UI contrast profile name")
    default: return String(localized: "Balanced", comment: "UI contrast profile name")
    }
  }

  static func scoringProfileDisplayName(_ profile: String) -> String {
    switch profile {
    case "Deep Focus":
      return String(localized: "Deep Focus", comment: "Insight scoring profile name")
    case "Recovery": return String(localized: "Recovery", comment: "Insight scoring profile name")
    default: return String(localized: "Balanced", comment: "Insight scoring profile name")
    }
  }

  static func menuBarDisplayName(_ value: String) -> String {
    switch value {
    case "Icon only":
      return String(localized: "Icon only", comment: "Menu bar display mode: icon only")
    case "Text only":
      return String(localized: "Text only", comment: "Menu bar display mode: text only")
    default:
      return String(localized: "Icon and text", comment: "Menu bar display mode: icon and text")
    }
  }
}
