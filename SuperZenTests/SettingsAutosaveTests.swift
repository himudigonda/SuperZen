import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct SettingsAutosaveTests {
  private let suiteName = "com.himudigonda.SuperZenTests.autosave.\(UUID().uuidString)"
  private let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
    SettingKey.registerDefaults(in: defaults)
  }

  @Test func defaultsAreValid() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(SettingsValidation.issues(in: defaults).isEmpty)
  }

  @Test func customValuesThatBreakTheCycleAreFlagged() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(60.0, forKey: SettingKey.workDuration)
    defaults.set(60.0, forKey: SettingKey.nudgeLeadTime)
    defaults.set(600.0, forKey: SettingKey.breakDuration)
    defaults.set(true, forKey: SettingKey.focusScheduleEnabled)
    defaults.set("", forKey: SettingKey.focusScheduleWeekdays)
    let issues = SettingsValidation.issues(in: defaults)
    #expect(issues == [.reminderNotShorterThanWork, .longBreakNotLongerThanShort, .scheduleHasNoWeekdays])
    #expect(issues.filter { $0.section == .breakSchedule }.count == 2)
    #expect(issues.allSatisfy { !$0.message.isEmpty })
  }

  @Test func turningLongBreaksOffClearsTheLengthIssue() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(600.0, forKey: SettingKey.breakDuration)
    defaults.set(0, forKey: SettingKey.longBreakEvery)
    #expect(SettingsValidation.issues(in: defaults).isEmpty)
  }

  @Test func newScheduleOptionsContainTheirDefaults() {
    #expect(SettingsCatalog.longBreakDurationOptions.map(\.1).contains(SettingsCatalog.longBreakDurationDefault))
    #expect(SettingsCatalog.longBreakEveryOptions.contains(SettingsCatalog.longBreakEveryDefault))
    #expect(SettingsCatalog.longBreakEveryOptions.contains(0))
    #expect(SettingsCatalog.typingDeferralCapOptions.map(\.1).contains(SettingsCatalog.typingDeferralCapDefault))
  }

  @Test func longBreakFrequencyLabelsUseOrdinals() {
    #expect(SettingsCatalog.ordinal(4, locale: Locale(identifier: "en_US")) == "4th")
    #expect(SettingsCatalog.ordinal(2, locale: Locale(identifier: "en_US")) == "2nd")
    let labels = SettingsCatalog.longBreakEveryOptions.map(SettingsCatalog.longBreakEveryDisplayName)
    #expect(Set(labels).count == labels.count)
  }

  @Test func savedChangesReachTheEngineWithoutASaveStep() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = StateManager(
      defaults: defaults, clock: ManualClock(Date(timeIntervalSince1970: 1_793_620_800)),
      activity: ScriptedActivity(), effects: RecordingEffects(), locker: FakeLocker(),
      hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
    defaults.set(2, forKey: SettingKey.longBreakEvery)
    defaults.set(900.0, forKey: SettingKey.longBreakDuration)
    defaults.set(30.0, forKey: SettingKey.typingDeferralCap)
    manager.reloadSettings()
    #expect(manager.session.settings.timer.longBreakEvery == 2)
    #expect(manager.session.settings.timer.longBreakDuration == 900)
    #expect(manager.session.settings.timer.typingDeferralCap == 30)
  }
}
