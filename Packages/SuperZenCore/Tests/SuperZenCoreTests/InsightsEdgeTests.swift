import Foundation
import Testing

@testable import SuperZenCore

private let sessionID = UUID()

private func active(from start: Date, seconds: TimeInterval) -> ActivityInterval {
  ActivityInterval(sessionID: sessionID, kind: .active, start: start, end: start.addingTimeInterval(seconds))
}

private func configuration(focusMinutes: Int = 60, window: TimeWindow? = nil) -> InsightsConfiguration {
  InsightsConfiguration(
    goals: InsightsGoals(focusMinutes: focusMinutes, breaks: 4, wellness: 4), workWindow: window)
}

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private let calculator = InsightsCalculator(calendar: .utc)

@Suite struct InsightsEdgeTests {
  @Test(arguments: InsightsRange.allCases)
  func emptyDataProducesNoNaNsAndNoData(range: InsightsRange) {
    let insights = calculator.compute(range, at: mondayNoon, data: TelemetrySnapshot(), configuration: configuration())
    #expect(!insights.hasData)
    #expect(insights.focus == 0 && insights.streakDays == 0 && insights.sessions == 0)
    #expect(insights.trend == nil && insights.focusRate == nil && insights.breakRate == nil)
    #expect(insights.focusGoalProgress == 0 && insights.breakGoalProgress == 0)
    #expect(insights.qualityScore == 50)
    #expect(insights.buckets.allSatisfy { $0.focus == 0 })
  }

  @Test func futureDatedActivityDoesNotCountTowardTodaysStreak() {
    let future = active(from: mondayNoon.addingTimeInterval(3600), seconds: 2 * 3600)
    let insights = calculator.compute(
      .week, at: mondayNoon, data: TelemetrySnapshot(activity: [future]), configuration: configuration())
    #expect(insights.focus == 0)
    #expect(insights.streakDays == 0)
  }

  @Test func futureDatedRecordsAreIgnoredByTotals() {
    let later = mondayNoon.addingTimeInterval(7200)
    let data = TelemetrySnapshot(
      activity: [active(from: later, seconds: 600)],
      breaks: [
        BreakRecord(kind: .short, result: .completed, start: later, end: later.addingTimeInterval(20), planned: 20)
      ],
      wellness: [WellnessRecord(kind: .blink, at: later, completed: true)])
    let insights = calculator.compute(.today, at: mondayNoon, data: data, configuration: configuration())
    #expect(insights.focus == 0 && insights.breaksTaken == 0 && insights.wellnessTotal == 0)
    #expect(!insights.hasData)
  }

  @Test func streakCountsConsecutiveGoalDaysAcrossFallBack() {
    let calendar = newYork()
    let ny = InsightsCalculator(calendar: calendar)
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
    let intervals = (0..<5).map { offset -> ActivityInterval in
      let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
      return active(from: calendar.date(byAdding: .hour, value: 9, to: day)!, seconds: 3600)
    }
    let insights = ny.compute(
      .month, at: now, data: TelemetrySnapshot(activity: intervals), configuration: configuration())
    #expect(insights.streakDays == 5)
  }

  @Test func streakCountsConsecutiveGoalDaysAcrossSpringForward() {
    let calendar = newYork()
    let ny = InsightsCalculator(calendar: calendar)
    let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
    let intervals = (0..<4).map { offset -> ActivityInterval in
      let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
      return active(from: calendar.date(byAdding: .hour, value: 10, to: day)!, seconds: 3600)
    }
    let insights = ny.compute(
      .month, at: now, data: TelemetrySnapshot(activity: intervals), configuration: configuration())
    #expect(insights.streakDays == 4)
  }

  @Test func longDayOfFallBackBucketsSumToTheTotal() {
    let calendar = newYork()
    let ny = InsightsCalculator(calendar: calendar)
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 59))!
    let data = TelemetrySnapshot(activity: [active(from: start, seconds: 4 * 3600)])
    let insights = ny.compute(.today, at: now, data: data, configuration: configuration())
    #expect(insights.buckets.count == 25)
    #expect(insights.buckets.reduce(0) { $0 + $1.focus } == insights.focus)
    #expect(insights.focus == 4 * 3600)
  }

  @Test func shortDayOfSpringForwardBucketsSumToTheTotal() {
    let calendar = newYork()
    let ny = InsightsCalculator(calendar: calendar)
    let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 59))!
    let data = TelemetrySnapshot(activity: [active(from: start, seconds: 2 * 3600)])
    let insights = ny.compute(.today, at: now, data: data, configuration: configuration())
    #expect(insights.buckets.count == 23)
    #expect(insights.buckets.reduce(0) { $0 + $1.focus } == insights.focus)
  }

  @Test func heatmapRejectsAbsurdDayCounts() {
    let heatmap = calculator.hourlyHeatmap(days: 200_000, at: mondayNoon, active: [])
    #expect(heatmap.days.count <= 366)
  }

  @Test func hugeLookbackDoesNotTrap() {
    let start = calculator.fetchStart(for: .month, at: mondayNoon, streakLookbackDays: .max)
    #expect(start.timeIntervalSince(mondayNoon).isFinite)
  }

  @Test func goalsAtTheIntegerLimitStayFinite() {
    let goals = InsightsGoals(focusMinutes: .max, breaks: .max, wellness: .max)
    let insights = calculator.compute(
      .month, at: mondayNoon, data: TelemetrySnapshot(activity: [active(from: utcDate(2026, 11, 2, 9), seconds: 600)]),
      configuration: InsightsConfiguration(goals: goals))
    #expect(insights.focusGoalProgress.isFinite && insights.breakGoalProgress.isFinite)
  }

  @Test func legacySessionsWithAbsurdDurationsAreCapped() {
    let records = LegacyTelemetry.convert(
      sessions: [LegacyTelemetry.Session(start: mondayNoon, activeSeconds: 1e15, idleSeconds: 1e15)],
      breaks: [LegacyTelemetry.Break(endedAt: mondayNoon, type: "Short", completed: true, duration: 1e15)],
      wellness: [])
    for record in records {
      switch record {
      case .activity(let interval): #expect(interval.duration <= ActivityInterval.maximumSpan)
      case .breakTaken(let record): #expect(record.rested <= ActivityInterval.maximumSpan)
      case .wellness: break
      }
    }
  }

  @Test func legacyInfiniteDatesStayOrdered() {
    let records = LegacyTelemetry.convert(
      sessions: [LegacyTelemetry.Session(start: mondayNoon, activeSeconds: .infinity, idleSeconds: -.infinity)],
      breaks: [LegacyTelemetry.Break(endedAt: mondayNoon, type: "", completed: false, duration: .nan)],
      wellness: [])
    #expect(records.count == 1)
  }

  @Test func recorderCapsAbsurdActiveSeconds() {
    var recorder = TelemetryRecorder()
    _ = recorder.record(.focusStarted, at: mondayNoon)
    _ = recorder.record(.activeTime(1e15), at: mondayNoon)
    let records = recorder.flush()
    for record in records {
      if case .activity(let interval) = record { #expect(interval.duration <= ActivityInterval.maximumSpan) }
    }
  }

  @Test func timelineOnAFutureDayIsEmpty() {
    let day = mondayNoon.addingTimeInterval(5 * 86_400)
    let timeline = calculator.timeline(
      on: day, at: mondayNoon, data: TelemetrySnapshot(activity: [active(from: day, seconds: 600)]))
    #expect(timeline.isEmpty)
    #expect(timeline.domain.duration >= 0)
  }

  @Test func zeroLengthWorkWindowFallsBackToTheWholeDay() {
    let window = TimeWindow(startMinute: 600, endMinute: 600)
    let insights = calculator.compute(
      .today, at: mondayNoon, data: TelemetrySnapshot(activity: [active(from: utcDate(2026, 11, 2, 9), seconds: 600)]),
      configuration: configuration(window: window))
    #expect(insights.forecast != .beforeWorkday(needed: 0))
  }
}
