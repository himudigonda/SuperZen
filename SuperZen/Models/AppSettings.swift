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
  static let appUsageTrackingEnabled = "appUsageTrackingEnabled"
  static let shortcutStartBreak = "shortcutStartBreak"
  static let shortcutTogglePause = "shortcutTogglePause"
  static let shortcutSkipBreak = "shortcutSkipBreak"
  static let hasCompletedOnboarding = "hasCompletedOnboarding"
  static let wellnessCadenceVersion = "wellnessCadenceVersion"
  static let maxPostpones = LegacyKey.maxPostpones.rawValue
  static let deferralApps = LegacyKey.deferralApps.rawValue
  static let deferralCap = LegacyKey.deferralCap.rawValue
  static let deferralDuringCalls = LegacyKey.deferralDuringCalls.rawValue
  static let deferralDuringFullscreen = LegacyKey.deferralDuringFullscreen.rawValue
  static let plannedBreaks = LegacyKey.plannedBreaks.rawValue
  static let breakTipsEnabled = "breakTipsEnabled"
  static let breakPresentation = "breakPresentation"

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
    wellnessCadenceVersion, maxPostpones, deferralApps, deferralCap, deferralDuringCalls,
    deferralDuringFullscreen, plannedBreaks, breakTipsEnabled, breakPresentation, appUsageTrackingEnabled,
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
      breakTipsEnabled: true,
      breakPresentation: SettingsCatalog.breakPresentationDefault,
      launchAtLogin: false,
      menuBarDisplay: SettingsCatalog.menuBarDisplayDefault,
      timerStyle: SettingsCatalog.timerStyleDefault,
      postureEnabled: true,
      postureFrequency: SettingsCatalog.postureFrequencyDefault,
      blinkEnabled: true,
      blinkFrequency: SettingsCatalog.blinkFrequencyDefault,
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
      appUsageTrackingEnabled: true,
      shortcutStartBreak: SettingsCatalog.shortcutStartBreakDefault,
      shortcutTogglePause: SettingsCatalog.shortcutTogglePauseDefault,
      shortcutSkipBreak: SettingsCatalog.shortcutSkipBreakDefault,
      hasCompletedOnboarding: false,
      wellnessCadenceVersion: 0,
      maxPostpones: TimerSettings().maxPostpones,
      deferralApps: DeferralSettings.csv(from: DeferralSettings().apps),
      deferralCap: DeferralSettings().cap,
      deferralDuringCalls: DeferralSettings().duringCalls,
      deferralDuringFullscreen: DeferralSettings().duringFullscreen,
      plannedBreaks: PlannedBreak.json(from: []),
    ])
  }
}
