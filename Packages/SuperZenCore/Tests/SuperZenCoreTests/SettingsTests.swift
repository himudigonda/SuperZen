import Foundation
import Testing

@testable import SuperZenCore

@Suite struct LegacyMigrationTests {
  @Test func missingKeysFallBackToNewDefaults() {
    let settings = LegacySettingsMigration.migrate { _ in nil }
    #expect(settings == Settings())
  }

  @Test func readsEveryLegacyValueType() {
    let legacy: [String: Any] = [
      "workDuration": 1500.0,
      "breakDuration": 300,
      "difficulty": "Hardcore",
      "nudgeLeadTime": "30",
      "dontShowWhileTyping": false,
      "postureEnabled": 0,
      "blinkFrequency": 600.0,
      "focusScheduleEnabled": true,
      "focusScheduleStartMinute": 480.0,
      "focusScheduleEndMinute": 1020,
      "focusScheduleWeekdays": "1,7",
      "quietHoursEnabled": 1,
      "forceResetFocusAfterBreak": false,
      "balancedSkipLockRatio": 0.35,
      "wellnessDurationMultiplier": 1.5,
      "focusIdleThreshold": 30,
    ]
    let settings = LegacySettingsMigration.migrate { legacy[$0] }
    #expect(settings.timer.workDuration == 1500)
    #expect(settings.timer.shortBreakDuration == 300)
    #expect(settings.skipPolicy.difficulty == .hardcore)
    #expect(settings.timer.nudgeLeadTime == 30)
    #expect(settings.timer.deferWhileTyping == false)
    #expect(settings.wellness.posture.enabled == false)
    #expect(settings.wellness.blink.interval == 600)
    #expect(settings.schedule.enabled)
    #expect(settings.schedule.window == TimeWindow(startMinute: 480, endMinute: 1020))
    #expect(settings.schedule.weekdays == [1, 7])
    #expect(settings.quietHours.enabled)
    #expect(settings.timer.resetFocusAfterBreak == false)
    #expect(settings.skipPolicy.balancedLockRatio == 0.35)
    #expect(settings.wellness.durationMultiplier == 1.5)
    #expect(settings.timer.idleThreshold == 30)
  }

  @Test func corruptValuesAreRepairedNotTrusted() {
    let legacy: [String: Any] = [
      "workDuration": 0.0,
      "difficulty": "Impossible",
      "balancedSkipLockRatio": 5.0,
      "focusScheduleWeekdays": "0,2,9,x",
      "quietHoursStartMinute": 5000,
      "waterFrequency": -10.0,
    ]
    let settings = LegacySettingsMigration.migrate { legacy[$0] }
    #expect(settings.timer.workDuration == 1200)
    #expect(settings.skipPolicy.difficulty == .balanced)
    #expect(settings.skipPolicy.balancedLockRatio == 0.9)
    #expect(settings.schedule.weekdays == [2])
    #expect(settings.quietHours.window.startMinute == 1439)
    #expect(settings.wellness.water.interval == 3600)
  }

  @Test func newKeysAreReadForLongBreaksAndTypingCap() {
    let legacy: [String: Any] = ["longBreakDuration": 600, "longBreakEvery": 3.0, "typingDeferralCap": 60]
    let settings = LegacySettingsMigration.migrate { legacy[$0] }
    #expect(settings.timer.longBreakDuration == 600)
    #expect(settings.timer.longBreakEvery == 3)
    #expect(settings.timer.typingDeferralCap == 60)
  }
}

@Suite struct SettingsModelTests {
  @Test func codecRoundTripsSettings() throws {
    var settings = Settings()
    settings.timer.workDuration = 1800
    settings.schedule.weekdays = [2, 4]
    settings.wellness.water.enabled = false
    let decoded = try SettingsCodec.decode(SettingsCodec.encode(settings))
    #expect(decoded == settings)
    #expect(decoded.version == Settings.currentVersion)
  }

  @Test func validationDropsNudgeLeadThatFillsTheFocusBlock() {
    var settings = Settings()
    settings.timer.workDuration = 30
    settings.timer.nudgeLeadTime = 60
    #expect(settings.validated().timer.nudgeLeadTime == 0)
    settings.timer.nudgeLeadTime = 30
    #expect(settings.validated().timer.nudgeLeadTime == 0)
    settings.timer.nudgeLeadTime = 29
    #expect(settings.validated().timer.nudgeLeadTime == 29)
  }

  @Test func outOfRangeStoredNumbersDoNotCrashLaunch() {
    let settings = LegacySettingsMigration.read { $0 == "longBreakEvery" ? 1e20 : nil }
    #expect(settings.timer.longBreakEvery == TimerSettings().longBreakEvery)
  }

  @Test func oneXInstallsKeepTheirTimingWhenTheyNeverSavedIt() {
    let updates = LegacyTimingMigration.updates(storedVersion: 0, hasCompletedOnboarding: true) { _ in false }
    #expect(updates == [.workDuration: 1500, .breakDuration: 300, .longBreakEvery: 0])
  }

  @Test func legacyTimingKeepsExplicitChoicesAndSkipsNewInstalls() {
    let keepsWork = LegacyTimingMigration.updates(storedVersion: 0, hasCompletedOnboarding: true) {
      $0 == .workDuration
    }
    #expect(keepsWork == [.breakDuration: 300, .longBreakEvery: 0])
    #expect(LegacyTimingMigration.updates(storedVersion: 0, hasCompletedOnboarding: false) { _ in false }.isEmpty)
    #expect(LegacyTimingMigration.updates(storedVersion: 1, hasCompletedOnboarding: true) { _ in false }.isEmpty)
  }

  @Test func naturalBreakThresholdNeverDropsBelowBreakLength() {
    var timer = TimerSettings()
    timer.shortBreakDuration = 600
    #expect(timer.naturalBreakThreshold == 600)
    #expect(TimerSettings().naturalBreakThreshold == 120)
  }

  @Test func wellnessMultiplierIsClampedForDisplay() {
    var wellness = WellnessSettings()
    wellness.durationMultiplier = 10
    #expect(wellness.displayDuration(of: .affirmation) == 4)
  }

  @Test(arguments: zip(BreakDifficulty.allCases, ["Casual", "Balanced", "Hardcore"]))
  func difficultyTokensStayStable(_ difficulty: BreakDifficulty, _ token: String) {
    #expect(difficulty.rawValue == token)
    #expect(BreakDifficulty(rawValue: token) == difficulty)
  }

  @Test(arguments: zip(WellnessKind.allCases, [0.75, 0.75, 0.75, 2.0]))
  func wellnessKindsKeepTokenAndDisplayLength(_ kind: WellnessKind, _ seconds: Double) {
    #expect(WellnessKind(rawValue: kind.rawValue) == kind)
    #expect(kind.displayDuration == seconds)
  }

  @Test func unknownTokensAreRejected() {
    #expect(BreakDifficulty(rawValue: "unknown") == nil)
    #expect(WellnessKind(rawValue: "Posture") == nil)
    #expect(WellnessKind.allCases.map(\.rawValue) == ["posture", "blink", "water", "affirmation"])
  }
}
