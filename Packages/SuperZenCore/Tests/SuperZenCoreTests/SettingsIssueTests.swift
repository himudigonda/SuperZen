import Foundation
import Testing

@testable import SuperZenCore

@Suite struct SettingsIssueTests {
  @Test func defaultsHaveNoIssues() {
    #expect(Settings().issues.isEmpty)
  }

  @Test func reminderMustBeShorterThanWork() {
    var settings = Settings()
    settings.timer.workDuration = 60
    settings.timer.nudgeLeadTime = 60
    #expect(settings.issues == [.reminderNotShorterThanWork])
  }

  @Test func longBreakMustBeLongerWhenEnabled() {
    var settings = Settings()
    settings.timer.shortBreakDuration = 300
    settings.timer.longBreakDuration = 300
    #expect(settings.issues == [.longBreakNotLongerThanShort])
    settings.timer.longBreakEvery = 0
    #expect(settings.issues.isEmpty)
  }

  @Test func enabledScheduleNeedsAWeekday() {
    var settings = Settings()
    settings.schedule.weekdays = []
    #expect(settings.issues.isEmpty)
    settings.schedule.enabled = true
    #expect(settings.issues == [.scheduleHasNoWeekdays])
  }

  @Test func readKeepsRawValuesWhileMigrateValidates() {
    let raw: [String: Any] = ["workDuration": 0.0, "nudgeLeadTime": 30.0]
    let read = LegacySettingsMigration.read { raw[$0] }
    let migrated = LegacySettingsMigration.migrate { raw[$0] }
    #expect(read.timer.workDuration == 0)
    #expect(read.issues.contains(.reminderNotShorterThanWork))
    #expect(migrated.timer.workDuration == TimerSettings().workDuration)
  }
}
