import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

private nonisolated struct Environment: CustomTestStringConvertible, Sendable {
  let calendarIdentifier: Calendar.Identifier
  let timeZoneIdentifier: String
  let localeIdentifier: String

  var testDescription: String { "\(calendarIdentifier) \(timeZoneIdentifier) \(localeIdentifier)" }

  var calendar: Calendar {
    var calendar = Calendar(identifier: calendarIdentifier)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
    calendar.locale = Locale(identifier: localeIdentifier)
    return calendar
  }
}

private nonisolated let environments: [Environment] = [
  Environment(calendarIdentifier: .gregorian, timeZoneIdentifier: "America/Los_Angeles", localeIdentifier: "en_US"),
  Environment(calendarIdentifier: .gregorian, timeZoneIdentifier: "America/New_York", localeIdentifier: "de_DE"),
  Environment(calendarIdentifier: .gregorian, timeZoneIdentifier: "Pacific/Kiritimati", localeIdentifier: "fr_FR"),
  Environment(calendarIdentifier: .gregorian, timeZoneIdentifier: "Pacific/Pago_Pago", localeIdentifier: "es_ES"),
  Environment(calendarIdentifier: .buddhist, timeZoneIdentifier: "Asia/Bangkok", localeIdentifier: "th_TH"),
  Environment(calendarIdentifier: .hebrew, timeZoneIdentifier: "Asia/Jerusalem", localeIdentifier: "he_IL"),
  Environment(
    calendarIdentifier: .islamicUmmAlQura, timeZoneIdentifier: "Asia/Riyadh", localeIdentifier: "ar_SA"),
  Environment(calendarIdentifier: .japanese, timeZoneIdentifier: "Asia/Tokyo", localeIdentifier: "ja_JP"),
  Environment(calendarIdentifier: .persian, timeZoneIdentifier: "Asia/Tehran", localeIdentifier: "fa_IR"),
  Environment(calendarIdentifier: .indian, timeZoneIdentifier: "Asia/Kolkata", localeIdentifier: "hi_IN"),
  Environment(calendarIdentifier: .republicOfChina, timeZoneIdentifier: "Asia/Taipei", localeIdentifier: "zh_TW"),
  Environment(calendarIdentifier: .iso8601, timeZoneIdentifier: "Europe/London", localeIdentifier: "en_GB"),
]

@MainActor
@Suite(.serialized)
struct EnvironmentRobustnessTests {
  private func defaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: "com.himudigonda.SuperZenTests.env.\(UUID().uuidString)")!
    SettingKey.registerDefaults(in: defaults)
    defaults.set(false, forKey: SettingKey.dataRetentionEnabled)
    return defaults
  }

  private func manager(
    defaults: UserDefaults, clock: ManualClock, calendar: Calendar,
    registrar: FakeHotkeyRegistrar = FakeHotkeyRegistrar()
  ) -> StateManager {
    StateManager(
      defaults: defaults, clock: clock, calendar: calendar, activity: ScriptedActivity(),
      effects: RecordingEffects(), locker: FakeLocker(), hotkeyRegistrar: registrar, startsAutomatically: false)
  }

  @Test(arguments: environments)
  fileprivate func scheduleAndDayProgressSurviveThreeDaysInAnyCalendar(_ environment: Environment) {
    let defaults = defaults()
    defaults.set(true, forKey: SettingKey.focusScheduleEnabled)
    defaults.set(true, forKey: SettingKey.dayProgressEnabled)
    defaults.set("1,2,3,4,5,6,7", forKey: SettingKey.focusScheduleWeekdays)
    let clock = ManualClock(Date(timeIntervalSince1970: 1_793_520_000))
    let manager = manager(defaults: defaults, clock: clock, calendar: environment.calendar)
    for _ in 0..<(3 * 24 * 4) {
      clock.advance(by: 900)
      manager.tick()
    }
    #expect(manager.dayProgress.fraction >= 0)
    #expect(manager.dayProgress.fraction <= 1)
  }

  @Test(arguments: environments)
  fileprivate func insightsComputeInAnyCalendar(_ environment: Environment) throws {
    let now = Date(timeIntervalSince1970: 1_793_620_800)
    let container = try TelemetryStore.makeInMemoryContainer()
    for dayOffset in 0..<40 {
      for hour in [0, 8, 13, 23] {
        let start = now.addingTimeInterval(-Double(dayOffset) * 86_400 - Double(hour) * 3600)
        container.mainContext.insertRecord(
          .activity(
            ActivityInterval(sessionID: UUID(), kind: .active, start: start, end: start.addingTimeInterval(1500))))
      }
    }
    container.mainContext.insertRecord(
      .breakTaken(
        BreakRecord(kind: .long, result: .completed, start: now, end: now.addingTimeInterval(300), planned: 300)))
    try container.mainContext.save()

    let viewModel = InsightsViewModel(
      calendar: environment.calendar, defaults: defaults(), notificationCenter: NotificationCenter(),
      clock: { now }, liveActivity: { nil }, clearData: { 0 })
    viewModel.load(context: container.mainContext)
    for range in InsightsViewModel.Range.allCases {
      viewModel.select(range)
      #expect(viewModel.loadFailed == false)
      #expect(viewModel.kpis.count == 4)
      #expect(viewModel.hasRangeData || range == .today)
    }
  }

  @Test func hostileStoredSettingsNeverTrapTheStateManager() {
    let defaults = defaults()
    let garbage: [String: Any] = [
      SettingKey.workDuration: Double.nan,
      SettingKey.breakDuration: Double.infinity,
      SettingKey.longBreakDuration: -5.0,
      SettingKey.longBreakEvery: 9_999_999_999_999,
      SettingKey.nudgeLeadTime: 1e300,
      SettingKey.difficulty: "impossible",
      SettingKey.balancedSkipLockRatio: Double.nan,
      SettingKey.wellnessDurationMultiplier: -1.0,
      SettingKey.postureFrequency: 0.0,
      SettingKey.blinkFrequency: Double.infinity,
      SettingKey.focusIdleThreshold: Double.nan,
      SettingKey.typingDeferralCap: -1.0,
      SettingKey.focusScheduleWeekdays: "9,x,,-3",
      SettingKey.focusScheduleStartMinute: -77,
      SettingKey.focusScheduleEndMinute: 99_999,
      SettingKey.dayProgressStartMinute: Int.max,
      SettingKey.dayProgressEndMinute: Int.min,
      SettingKey.quietHoursStartMinute: 1e12,
      SettingKey.alertPosition: "diagonal",
      SettingKey.shortcutStartBreak: "💥",
      SettingKey.shortcutTogglePause: "⌘",
      SettingKey.shortcutSkipBreak: "",
      SettingKey.menuBarDisplay: ["not", "a", "string"],
      SettingKey.timerStyle: 42,
    ]
    for (key, value) in garbage { defaults.set(value, forKey: key) }
    defaults.set(true, forKey: SettingKey.focusScheduleEnabled)
    defaults.set(true, forKey: SettingKey.dayProgressEnabled)
    defaults.set(true, forKey: SettingKey.quietHoursEnabled)

    let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
    let registrar = FakeHotkeyRegistrar()
    let manager = manager(defaults: defaults, clock: clock, calendar: .current, registrar: registrar)
    for _ in 0..<600 {
      clock.advance(by: 1)
      manager.tick()
    }
    manager.reloadSettings()
    manager.startBreak()
    manager.skipBreak()
    _ = SettingsValidation.issues(in: defaults)
    manager.hotkeys.reload()
    #expect(InsightsFormat.duration(manager.timeRemaining) != "")
    #expect(!SpokenTimeFormatter.spokenTime(manager.timeRemaining).isEmpty)
  }
}
