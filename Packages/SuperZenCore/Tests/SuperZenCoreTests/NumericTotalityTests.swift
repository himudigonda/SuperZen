import Foundation
import Testing

@testable import SuperZenCore

private let hostileSeconds: [TimeInterval] = [
  .infinity, -.infinity, .nan, 1e20, -1e20, .greatestFiniteMagnitude, Double(Int.max),
]

@Suite struct NumericTotalityTests {
  @Test(arguments: TimerStyle.allCases, hostileSeconds)
  func timerStyleFormatsAnyValue(style: TimerStyle, seconds: TimeInterval) {
    #expect(!style.format(seconds).isEmpty)
  }

  @Test(arguments: DayProgressMetric.allCases, hostileSeconds)
  func dayProgressLabelsAnyValue(metric: DayProgressMetric, seconds: TimeInterval) {
    let progress = DayProgress(fraction: seconds, elapsed: seconds, remaining: seconds)
    #expect(!metric.label(for: progress).isEmpty)
  }

  @Test func clockFormatSaturatesInsteadOfWrapping() {
    #expect(TimerStyle.clock.format(.infinity) == TimerStyle.clock.format(1e20))
    #expect(TimerStyle.clock.format(.nan) == "0:00")
    #expect(TimerStyle.clock.format(-5) == "0:00")
  }

  @Test(arguments: hostileSeconds)
  func snapshotSurvivesOutOfRangeDeadlines(seconds: TimeInterval) {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1190)
    harness.send(.snooze(seconds))
    harness.send(.startBreak)
    harness.send(.extendBreak(seconds))
    let snapshot = MenuBarSnapshot(state: harness.state, at: harness.now)
    #expect(snapshot.remaining.isFinite)
    #expect(!TimerStyle.clock.format(snapshot.remaining).isEmpty)
  }

  @Test func hostileDurationsAreBoundedByValidation() {
    var settings = Settings()
    settings.timer.workDuration = 1e20
    settings.timer.shortBreakDuration = 1e20
    settings.timer.longBreakDuration = .greatestFiniteMagnitude
    settings.timer.nudgeLeadTime = 1e19
    settings.timer.typingDeferralCap = .infinity
    settings.timer.naturalBreakMinimum = .infinity
    settings.timer.idleThreshold = 1e20
    settings.timer.snoozeDuration = 1e20
    for kind in WellnessKind.allCases { settings.wellness[kind].interval = 1e20 }
    let valid = settings.validated()
    let timer = valid.timer
    let limit = Settings.maximumDuration
    let durations = [
      timer.workDuration, timer.shortBreakDuration, timer.longBreakDuration, timer.nudgeLeadTime,
      timer.typingDeferralCap, timer.naturalBreakMinimum, timer.idleThreshold, timer.snoozeDuration,
    ]
    for value in durations + WellnessKind.allCases.map({ valid.wellness[$0].interval }) {
      #expect(value.isFinite && value <= limit)
    }
  }

  @Test func decodedOutOfRangeDurationsAreBounded() throws {
    var settings = Settings()
    settings.timer.typingDeferralCap = 1e20
    let decoded = try SettingsCodec.decode(SettingsCodec.encode(settings))
    #expect(decoded.timer.typingDeferralCap <= Settings.maximumDuration)
  }

  @Test func decodedWindowsStayInsideTheDay() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
    for (section, start, end) in [("schedule", -40, 99_999), ("quietHours", 2000, 3000)] {
      var values = try #require(object[section] as? [String: Any])
      values["window"] = ["startMinute": start, "endMinute": end]
      object[section] = values
    }
    let decoded = try SettingsCodec.decode(JSONSerialization.data(withJSONObject: object))
    for window in [decoded.schedule.window, decoded.quietHours.window] {
      #expect((0..<TimeWindow.minutesPerDay).contains(window.startMinute))
      #expect((0..<TimeWindow.minutesPerDay).contains(window.endMinute))
    }
  }

  @Test(arguments: ["1e400", "-1e400", "nan", "inf", "1e308", " 5 ", "0x10", "", "٣"])
  func legacyStringsNeverBreakValidation(raw: String) {
    let timer = LegacySettingsMigration.migrate { _ in raw }.timer
    for value in [timer.workDuration, timer.typingDeferralCap, timer.naturalBreakMinimum, timer.nudgeLeadTime] {
      #expect(value.isFinite && value <= Settings.maximumDuration)
    }
  }

  @Test(arguments: [Double.nan, .infinity, -.infinity, 1e300, -1e300, 3.9, -3.9])
  func legacyDoublesNeverBreakValidation(value: Double) {
    let timer = LegacySettingsMigration.migrate { _ in value }.timer
    #expect(timer.longBreakEvery >= 0)
    for duration in [timer.typingDeferralCap, timer.nudgeLeadTime, timer.naturalBreakMinimum] {
      #expect(duration.isFinite && duration <= Settings.maximumDuration)
    }
  }
}
