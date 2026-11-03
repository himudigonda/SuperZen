import Foundation
import Testing

@testable import SuperZenCore

@Suite struct LegacyHostileInputTests {
  @Test func wrongTypesFallBackToDefaults() {
    let hostile: [String: Any] = [
      "workDuration": [1, 2], "breakDuration": Date(), "longBreakEvery": "many", "difficulty": 7,
      "dontShowWhileTyping": "maybe", "postureEnabled": Data(), "focusScheduleWeekdays": 12,
      "focusScheduleStartMinute": "late", "quietHoursEndMinute": [1],
    ]
    let settings = LegacySettingsMigration.migrate { hostile[$0] }
    #expect(settings == Settings())
  }

  @Test func numericStringsAreAcceptedAndJunkIsIgnored() {
    let values: [String: Any] = ["workDuration": "1800", "breakDuration": "twenty", "longBreakEvery": "3"]
    let settings = LegacySettingsMigration.migrate { values[$0] }
    #expect(settings.timer.workDuration == 1800)
    #expect(settings.timer.shortBreakDuration == TimerSettings().shortBreakDuration)
    #expect(settings.timer.longBreakEvery == 3)
  }

  @Test func negativeAndFractionalCountsAreRepaired() {
    let values: [String: Any] = ["longBreakEvery": -4.0, "focusScheduleStartMinute": -30.7]
    let settings = LegacySettingsMigration.migrate { values[$0] }
    #expect(settings.timer.longBreakEvery == 0)
    #expect(settings.schedule.window.startMinute == 0)
  }

  @Test func wellnessKeysAcceptBooleansAndIntegersAlike() {
    let values: [String: Any] = [
      "postureEnabled": true, "blinkEnabled": 0, "waterEnabled": "false", "affirmationEnabled": 2,
    ]
    let settings = LegacySettingsMigration.migrate { values[$0] }
    #expect(settings.wellness.posture.enabled)
    #expect(!settings.wellness.blink.enabled)
    #expect(!settings.wellness.water.enabled)
    #expect(settings.wellness.affirmation.enabled)
  }

  @Test func nanEverywhereStillYieldsValidSettings() {
    let settings = LegacySettingsMigration.migrate { _ in Double.nan }
    #expect(settings == settings.validated())
    #expect(settings.timer.workDuration == TimerSettings().workDuration)
  }

  @Test func everyKeyWithAHugeValueYieldsBoundedSettings() {
    let settings = LegacySettingsMigration.migrate { _ in Double.greatestFiniteMagnitude }
    #expect(settings == settings.validated())
    #expect(settings.timer.workDuration <= Settings.maximumDuration)
  }

  @Test func migratedSettingsAlwaysRunTheEngine() {
    let raws: [Any] = [Double.nan, Double.infinity, -1.0, 0.0, 1e300, "9e99", Int.max, Int.min]
    for raw in raws {
      let settings = LegacySettingsMigration.migrate { _ in raw }
      var harness = Harness(settings: settings)
      harness.run(for: 30)
      #expect(harness.remaining.isFinite, "raw \(raw)")
    }
  }
}
