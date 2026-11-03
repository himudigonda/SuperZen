import Foundation
import Testing

@testable import SuperZenCore

private let sessionA = UUID()
private let sessionB = UUID()

private func span(
  _ kind: ActivityKind = .active, from start: Date, seconds: TimeInterval, session: UUID = sessionA
) -> ActivityInterval {
  ActivityInterval(sessionID: session, kind: kind, start: start, end: start.addingTimeInterval(seconds))
}

private func breakRecord(_ result: BreakResult, at end: Date) -> BreakRecord {
  BreakRecord(kind: .short, result: result, start: end.addingTimeInterval(-20), end: end, planned: 20)
}

private func config(focusMinutes: Int = 60, window: TimeWindow? = nil) -> InsightsConfiguration {
  InsightsConfiguration(
    goals: InsightsGoals(focusMinutes: focusMinutes, breaks: 4, wellness: 4),
    workWindow: window,
    interruptionThreshold: 30)
}

private let utcCalculator = InsightsCalculator(calendar: .utc)

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private func nyDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
  newYork().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite struct InsightsTotalsTests {
  @Test func focusIsClippedToTheRangeAndSplitAtMidnight() {
    let now = utcDate(2026, 11, 3, 1)
    let data = TelemetrySnapshot(activity: [span(from: utcDate(2026, 11, 2, 23, 30), seconds: 3600)])
    let today = utcCalculator.compute(.today, at: now, data: data, configuration: config())
    #expect(today.focus == 1800)
    #expect(today.buckets.count == 24)
    #expect(today.buckets[0].focus == 1800)

    let week = utcCalculator.compute(.week, at: now, data: data, configuration: config())
    #expect(week.focus == 3600)
    #expect(week.buckets.suffix(2).map(\.focus) == [1800, 1800])
    #expect(week.activeDays == 2)
  }

  @Test func sessionsUseFocusTimeWithinTheRange() {
    let data = TelemetrySnapshot(activity: [
      span(from: utcDate(2026, 11, 2, 9), seconds: 600),
      span(.idle, from: utcDate(2026, 11, 2, 9, 10), seconds: 60),
      span(from: utcDate(2026, 11, 2, 9, 11), seconds: 600),
      span(from: utcDate(2026, 11, 2, 10), seconds: 300, session: sessionB),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.sessions == 2)
    #expect(insights.longestSession == 1200)
    #expect(insights.averageSession == 750)
    #expect(insights.idle == 60)
    #expect(insights.focusRate == 1500.0 / 1560.0)
  }

  @Test func ratesCountNaturalBreaksAsTaken() {
    let data = TelemetrySnapshot(breaks: [
      breakRecord(.completed, at: utcDate(2026, 11, 2, 9)),
      breakRecord(.natural, at: utcDate(2026, 11, 2, 10)),
      breakRecord(.skipped, at: utcDate(2026, 11, 2, 11)),
      breakRecord(.skipped, at: utcDate(2026, 11, 1, 11)),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.breaksTaken == 2)
    #expect(insights.breaksSkipped == 1)
    #expect(insights.breakRate == 2.0 / 3.0)
    #expect(insights.skipRate == 1.0 / 3.0)
    #expect(insights.breakGoalProgress == 0.5)
  }

  @Test func wellnessIsTalliedPerKind() {
    let data = TelemetrySnapshot(wellness: [
      WellnessRecord(kind: .posture, at: utcDate(2026, 11, 2, 9), completed: true),
      WellnessRecord(kind: .posture, at: utcDate(2026, 11, 2, 10), completed: false),
      WellnessRecord(kind: .water, at: utcDate(2026, 11, 2, 11), completed: true),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.wellnessCompleted == 2)
    #expect(insights.wellnessTotal == 3)
    #expect(insights.wellnessByKind.first { $0.kind == .posture }?.rate == 0.5)
    #expect(insights.wellnessByKind.first { $0.kind == .blink }?.rate == nil)
  }

  @Test func idleRunSplitAcrossRowsCountsAsOneInterruption() {
    let start = utcDate(2026, 11, 2, 9)
    let data = TelemetrySnapshot(activity: [
      span(from: start, seconds: 600),
      span(.idle, from: start.addingTimeInterval(600), seconds: 20),
      span(.idle, from: start.addingTimeInterval(620), seconds: 300),
      span(from: start.addingTimeInterval(920), seconds: 60),
      span(.idle, from: start.addingTimeInterval(980), seconds: 10),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.interruptions == 1)
  }

  @Test func bestBucketIsTheBusiestHour() {
    let data = TelemetrySnapshot(activity: [
      span(from: utcDate(2026, 11, 2, 9), seconds: 600),
      span(from: utcDate(2026, 11, 2, 10), seconds: 1800),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.bestBucket?.interval.start == utcDate(2026, 11, 2, 10))
    let empty = utcCalculator.compute(.today, at: mondayNoon, data: TelemetrySnapshot(), configuration: config())
    #expect(empty.bestBucket == nil)
  }
}

@Suite struct InsightsCalendarTests {
  @Test func springForwardDayHasTwentyThreeHourBuckets() {
    let calculator = InsightsCalculator(calendar: newYork())
    let now = nyDate(2026, 3, 8, 12)
    let data = TelemetrySnapshot(activity: [span(from: nyDate(2026, 3, 8, 1, 30), seconds: 3600)])
    let insights = calculator.compute(.today, at: now, data: data, configuration: config())
    #expect(insights.buckets.count == 23)
    #expect(insights.focus == 3600)
    #expect(insights.buckets.reduce(0) { $0 + $1.focus } == 3600)
    #expect(insights.buckets[1].focus == 1800)
    #expect(insights.buckets[2].focus == 1800)
  }

  @Test func fallBackDayHasTwentyFiveHourBuckets() {
    let calculator = InsightsCalculator(calendar: newYork())
    let now = nyDate(2026, 11, 1, 12)
    let start = nyDate(2026, 11, 1, 0, 30)
    let data = TelemetrySnapshot(activity: [span(from: start, seconds: 3 * 3600)])
    let insights = calculator.compute(.today, at: now, data: data, configuration: config())
    #expect(insights.buckets.count == 25)
    #expect(insights.focus == 3 * 3600)
    #expect(insights.buckets.prefix(4).map(\.focus) == [1800, 3600, 3600, 1800])
  }

  @Test func weekBucketsFollowLocalDaysAcrossDST() {
    let calculator = InsightsCalculator(calendar: newYork())
    let now = nyDate(2026, 11, 3, 12)
    let insights = calculator.compute(.week, at: now, data: TelemetrySnapshot(), configuration: config())
    #expect(insights.buckets.count == 7)
    #expect(insights.buckets.map(\.interval.duration).contains(25 * 3600))
    #expect(insights.buckets.first?.interval.start == nyDate(2026, 10, 28, 0))
  }

  @Test func trendComparesTheSameElapsedSlice() {
    let data = TelemetrySnapshot(activity: [
      span(from: utcDate(2026, 11, 2, 9), seconds: 3600),
      span(from: utcDate(2026, 11, 1, 9), seconds: 1800),
      span(from: utcDate(2026, 11, 1, 15), seconds: 7200),
    ])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.trend == 1.0)
    let none = utcCalculator.compute(
      .today, at: mondayNoon, data: TelemetrySnapshot(activity: [data.activity[0]]), configuration: config())
    #expect(none.trend == nil)
  }

  @Test func fetchStartCoversComparisonAndStreak() {
    let start = utcCalculator.fetchStart(for: .month, at: mondayNoon, streakLookbackDays: 35)
    #expect(start == utcDate(2026, 9, 4))
    let short = utcCalculator.fetchStart(for: .today, at: mondayNoon, streakLookbackDays: 35)
    #expect(short == utcDate(2026, 9, 28))
  }
}

@Suite struct InsightsStreakTests {
  private func days(_ offsets: [Int], seconds: TimeInterval = 3600) -> [ActivityInterval] {
    offsets.map { span(from: utcDate(2026, 11, 2 - $0, 9), seconds: seconds) }
  }

  @Test func streakCountsTodayOnceTheGoalIsMet() {
    let streak = utcCalculator.streak(active: days([0, 1, 2]), goal: 3600, at: mondayNoon)
    #expect(streak == 3)
  }

  @Test func unfinishedTodayDoesNotBreakTheStreak() {
    let streak = utcCalculator.streak(
      active: days([1, 2]) + [span(from: utcDate(2026, 11, 2, 9), seconds: 60)], goal: 3600, at: mondayNoon)
    #expect(streak == 2)
  }

  @Test func missedDayEndsTheStreak() {
    #expect(utcCalculator.streak(active: days([0, 2, 3]), goal: 3600, at: mondayNoon) == 1)
    #expect(utcCalculator.streak(active: [], goal: 3600, at: mondayNoon) == 0)
  }

  @Test func goalSplitAcrossMidnightIsCreditedToEachDay() {
    let active = [span(from: utcDate(2026, 11, 1, 23), seconds: 7200)]
    #expect(utcCalculator.streak(active: active, goal: 3600, at: mondayNoon) == 2)
  }
}

@Suite struct InsightsScoreTests {
  @Test func noDataIsNeutral() {
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: TelemetrySnapshot(), configuration: config())
    #expect(insights.qualityScore == 50)
    #expect(!insights.hasData)
    #expect(insights.focusRate == nil)
    #expect(insights.breakRate == nil)
  }

  @Test func perfectDayScoresFull() {
    let data = TelemetrySnapshot(
      activity: [span(from: utcDate(2026, 11, 2, 9), seconds: 3600)],
      breaks: [breakRecord(.completed, at: utcDate(2026, 11, 2, 10))],
      wellness: [WellnessRecord(kind: .blink, at: utcDate(2026, 11, 2, 10), completed: true)])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.qualityScore == 100)
    #expect(insights.hasData)
  }

  @Test func focusWithoutBreaksIsNotPunishedForMissingData() {
    let data = TelemetrySnapshot(activity: [span(from: utcDate(2026, 11, 2, 9), seconds: 600)])
    let insights = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: config())
    #expect(insights.qualityScore == 80)
  }

  @Test func profilesChangeTheWeighting() {
    let data = TelemetrySnapshot(
      activity: [span(from: utcDate(2026, 11, 2, 9), seconds: 3600)],
      breaks: [breakRecord(.skipped, at: utcDate(2026, 11, 2, 10))])
    var deep = config()
    deep.profile = .deepFocus
    var recovery = config()
    recovery.profile = .recovery
    let deepScore = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: deep).qualityScore
    let recoveryScore = utcCalculator.compute(.today, at: mondayNoon, data: data, configuration: recovery).qualityScore
    #expect(deepScore > recoveryScore)
  }
}

@Suite struct InsightsForecastTests {
  private let workday = TimeWindow(startMinute: 540, endMinute: 1080)

  private func forecast(at now: Date, focus seconds: TimeInterval, from start: Date, goal: Int = 240) -> Forecast {
    let data = TelemetrySnapshot(activity: seconds > 0 ? [span(from: start, seconds: seconds)] : [])
    return utcCalculator.compute(
      .today, at: now, data: data, configuration: config(focusMinutes: goal, window: workday)
    )
    .forecast
  }

  @Test func beforeTheWorkdayReportsWhatIsNeeded() {
    #expect(forecast(at: utcDate(2026, 11, 2, 8), focus: 0, from: mondayNoon) == .beforeWorkday(needed: 14_400))
  }

  @Test func earlyInTheDayGathersPaceFirst() {
    let now = utcDate(2026, 11, 2, 9, 10)
    #expect(forecast(at: now, focus: 300, from: utcDate(2026, 11, 2, 9)) == .gatheringPace(needed: 14_100))
  }

  @Test func paceIsMeasuredFromTheWorkdayStartNotMidnight() {
    let now = utcDate(2026, 11, 2, 11)
    let result = forecast(at: now, focus: 3600, from: utcDate(2026, 11, 2, 9))
    #expect(result == .onTrack(eta: utcDate(2026, 11, 2, 17)))
  }

  @Test func slowPaceProjectsAShortfallAtTheEndOfTheWorkday() {
    let now = utcDate(2026, 11, 2, 13)
    let result = forecast(at: now, focus: 3600, from: utcDate(2026, 11, 2, 9))
    #expect(result == .shortfall(projected: 3600 + 0.25 * 5 * 3600, goal: 14_400))
  }

  @Test func afterTheWorkdayReportsTheGap() {
    let now = utcDate(2026, 11, 2, 19)
    #expect(forecast(at: now, focus: 3600, from: utcDate(2026, 11, 2, 9)) == .workdayOver(shortBy: 10_800))
  }

  @Test func metGoalWins() {
    #expect(forecast(at: mondayNoon, focus: 3600, from: utcDate(2026, 11, 2, 9), goal: 60) == .goalMet)
  }

  @Test func weekPaceComparesAgainstElapsedWorkdays() {
    let now = utcDate(2026, 11, 2, 18)
    let data = TelemetrySnapshot(activity: [span(from: utcDate(2026, 10, 30, 9), seconds: 7 * 3600)])
    let insights = utcCalculator.compute(
      .week, at: now, data: data, configuration: config(focusMinutes: 60, window: workday))
    #expect(insights.forecast == .pace(delta: 0))
  }

  @Test func streakSurvivesADayWhoseMidnightIsSkipped() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Santiago")!
    let calculator = InsightsCalculator(calendar: calendar)
    let noon = { (day: Int, month: Int) in
      calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }
    let active = [noon(5, 9), noon(6, 9), noon(7, 9)].map {
      ActivityInterval(sessionID: UUID(), kind: .active, start: $0, end: $0.addingTimeInterval(3600))
    }
    #expect(calendar.component(.hour, from: calendar.startOfDay(for: noon(6, 9))) == 1)
    #expect(calculator.streak(active: active, goal: 3600, at: noon(7, 9).addingTimeInterval(3600)) == 3)
  }
}
