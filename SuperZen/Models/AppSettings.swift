import Foundation
import SuperZenCore

extension BreakDifficulty {
  nonisolated var displayName: String {
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
  static let workDuration = LegacyKey.workDuration.rawValue
  static let breakDuration = LegacyKey.breakDuration.rawValue
  static let difficulty = LegacyKey.difficulty.rawValue
  static let nudgeLeadTime = LegacyKey.nudgeLeadTime.rawValue
  static let dontShowWhileTyping = LegacyKey.dontShowWhileTyping.rawValue
  static let launchAtLogin = "launchAtLogin"
  static let menuBarDisplay = "menuBarDisplay"
  static let timerStyle = "timerStyle"
  static let postureEnabled = LegacyKey.postureEnabled.rawValue
  static let postureFrequency = LegacyKey.postureFrequency.rawValue
  static let blinkEnabled = LegacyKey.blinkEnabled.rawValue
  static let blinkFrequency = LegacyKey.blinkFrequency.rawValue
  static let dimScreenWellness = "dimScreenWellness"
  static let waterEnabled = LegacyKey.waterEnabled.rawValue
  static let waterFrequency = LegacyKey.waterFrequency.rawValue
  static let affirmationEnabled = LegacyKey.affirmationEnabled.rawValue
  static let affirmationFrequency = LegacyKey.affirmationFrequency.rawValue
  static let focusIdleThreshold = LegacyKey.focusIdleThreshold.rawValue
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
  static let focusScheduleEnabled = LegacyKey.focusScheduleEnabled.rawValue
  static let focusScheduleStartMinute = LegacyKey.focusScheduleStartMinute.rawValue
  static let focusScheduleEndMinute = LegacyKey.focusScheduleEndMinute.rawValue
  static let focusScheduleWeekdays = LegacyKey.focusScheduleWeekdays.rawValue
  static let longBreakDuration = LegacyKey.longBreakDuration.rawValue
  static let longBreakEvery = LegacyKey.longBreakEvery.rawValue
  static let typingDeferralCap = LegacyKey.typingDeferralCap.rawValue
  static let focusScheduleAutoResume = LegacyKey.focusScheduleAutoResume.rawValue
  static let dayProgressEnabled = "dayProgressEnabled"
  static let dayProgressStartMinute = "dayProgressStartMinute"
  static let dayProgressEndMinute = "dayProgressEndMinute"
  static let dayProgressBarStyle = "dayProgressBarStyle"
  static let dayProgressMetric = "dayProgressMetric"
  static let dayProgressFills = "dayProgressFills"  // true = fills left→right, false = depletes
  static let quietHoursEnabled = LegacyKey.quietHoursEnabled.rawValue
  static let quietHoursStartMinute = LegacyKey.quietHoursStartMinute.rawValue
  static let quietHoursEndMinute = LegacyKey.quietHoursEndMinute.rawValue
  static let dailyFocusGoalMinutes = "dailyFocusGoalMinutes"
  static let dailyBreakGoalCount = "dailyBreakGoalCount"
  static let dailyWellnessGoalCount = "dailyWellnessGoalCount"
  static let insightsShowGoalLine = "insightsShowGoalLine"
  static let uiAccentPalette = "uiAccentPalette"
  static let uiContrastProfile = "uiContrastProfile"
  static let forceResetFocusAfterBreak = LegacyKey.forceResetFocusAfterBreak.rawValue
  static let balancedSkipLockRatio = LegacyKey.balancedSkipLockRatio.rawValue
  static let wellnessDurationMultiplier = LegacyKey.wellnessDurationMultiplier.rawValue
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
    shortcutSkipBreak, hasCompletedOnboarding, longBreakDuration, longBreakEvery, typingDeferralCap,
  ]

  /// Call once at app launch so UserDefaults always has sane values even before
  /// the user has opened Settings for the first time. Every value below is sourced from
  /// `SettingsCatalog` — this function must never contain a literal that isn't also the
  /// literal backing a `SettingsCatalog.xDefault`/`xOptions` entry.
  static func registerDefaults(in defaults: UserDefaults = .standard) {
    defaults.register(defaults: [
      workDuration: SettingsCatalog.workDurationDefault,
      breakDuration: SettingsCatalog.breakDurationDefault,
      longBreakDuration: SettingsCatalog.longBreakDurationDefault,
      longBreakEvery: SettingsCatalog.longBreakEveryDefault,
      typingDeferralCap: SettingsCatalog.typingDeferralCapDefault,
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

  static let workDurationDefault: Double = TimerSettings().workDuration
  static let workDurationOptions: [(String, Double)] = [
    ("20 minutes", 1200),
    ("25 minutes", 1500),
    ("30 minutes", 1800),
    ("45 minutes", 2700),
    ("60 minutes", 3600),
    ("90 minutes", 5400),
  ]

  static let breakDurationDefault: Double = TimerSettings().shortBreakDuration
  static let longBreakDurationDefault: Double = TimerSettings().longBreakDuration
  static let longBreakEveryDefault: Int = TimerSettings().longBreakEvery
  static let typingDeferralCapDefault: Double = TimerSettings().typingDeferralCap
  static let longBreakDurationOptions: [(String, Double)] = [
    ("2 minutes", 120),
    ("5 minutes", 300),
    ("10 minutes", 600),
    ("15 minutes", 900),
  ]
  static let longBreakEveryOptions = [0, 2, 3, 4, 5, 6]
  static let typingDeferralCapOptions: [(String, Double)] = [
    ("30 seconds", 30),
    ("1 minute", 60),
    ("2 minutes", 120),
    ("5 minutes", 300),
  ]

  static func longBreakEveryDisplayName(_ every: Int) -> String {
    every <= 0
      ? String(localized: "Never", comment: "Long break frequency option: long breaks off")
      : String(
        localized: "Every \(ordinal(every)) break",
        comment: "Long break frequency option, with an ordinal such as 4th")
  }

  static func ordinal(_ value: Int, locale: Locale = .current) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    formatter.locale = locale
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
  }

  static let breakDurationOptions: [(String, Double)] = [
    ("20 seconds", 20),
    ("1 minute", 60),
    ("5 minutes", 300),
    ("10 minutes", 600),
  ]

  static let nudgeLeadTimeDefault: Double = TimerSettings().nudgeLeadTime
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
  static let maxSkipLockSeconds: Double = SkipPolicy.maxLockSeconds
  static let balancedSkipLockRatioDefault: Double = SkipPolicy().balancedLockRatio
  /// Runtime clamp is intentionally wider than `balancedSkipLockOptions` (which is what the
  /// UI offers) so a value written outside the UI's own range still behaves sanely.
  static let balancedSkipLockRatioClamp: ClosedRange<Double> = SkipPolicy.lockRatioRange
  static let balancedSkipLockOptions: [(String, Double)] = [
    ("20% of break", 0.2),
    ("35% of break", 0.35),
    ("50% of break", 0.5),
    ("65% of break", 0.65),
    ("80% of break", 0.8),
  ]

  static let defaultSnoozeDuration: TimeInterval = TimerSettings().snoozeDuration

  // MARK: - Wellness reminders

  /// Posture/blink default cadence — short, frequent nudges.
  static let shortWellnessFrequencyDefault: Double = WellnessSettings().posture.interval
  /// Water/affirmation default cadence — longer, less frequent nudges.
  static let longWellnessFrequencyDefault: Double = WellnessSettings().water.interval
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

  static let wellnessDurationMultiplierDefault: Double = WellnessSettings().durationMultiplier
  static let wellnessDurationMultiplierClamp: ClosedRange<Double> = WellnessSettings.multiplierRange
  static let wellnessDurationMultiplierOptions: [(String, Double)] = [
    ("0.25x", 0.25),
    ("0.5x", 0.5),
    ("0.75x", 0.75),
    ("1.0x", 1.0),
    ("1.5x", 1.5),
    ("2.0x", 2.0),
  ]

  // MARK: - Focus telemetry

  static let idleThresholdDefault: Double = TimerSettings().idleThreshold
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
