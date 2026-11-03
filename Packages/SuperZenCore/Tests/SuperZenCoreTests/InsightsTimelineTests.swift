import Foundation
import Testing

@testable import SuperZenCore

private let calculator = InsightsCalculator(calendar: .utc)
private let session = UUID()

private func activity(_ kind: ActivityKind, _ hour: Int, _ minute: Int, minutes: Double) -> ActivityInterval {
  let start = utcDate(2026, 11, 2, hour, minute)
  return ActivityInterval(sessionID: session, kind: kind, start: start, end: start.addingTimeInterval(minutes * 60))
}

private func rest(_ result: BreakResult, endingAt hour: Int, _ minute: Int, seconds: TimeInterval) -> BreakRecord {
  let end = utcDate(2026, 11, 2, hour, minute)
  return BreakRecord(kind: .short, result: result, start: end.addingTimeInterval(-seconds), end: end, planned: 20)
}

@Suite struct DayTimelineTests {
  @Test func emptyDayGetsAMinimumWindowEndingNow() {
    let timeline = calculator.timeline(on: mondayNoon, at: mondayNoon, data: TelemetrySnapshot())
    #expect(timeline.isEmpty)
    #expect(timeline.domain == DateInterval(start: utcDate(2026, 11, 2, 8), end: utcDate(2026, 11, 2, 12)))
  }

  @Test func lanesAreSplitCoalescedAndClippedToNow() {
    let data = TelemetrySnapshot(
      activity: [
        activity(.active, 9, 0, minutes: 20),
        activity(.active, 9, 20, minutes: 10),
        activity(.idle, 9, 30, minutes: 5),
        activity(.active, 9, 35, minutes: 25),
        activity(.active, 11, 50, minutes: 30),
      ],
      breaks: [
        rest(.completed, endingAt: 10, 0, seconds: 20),
        rest(.skipped, endingAt: 10, 30, seconds: 0),
        rest(.natural, endingAt: 11, 0, seconds: 600),
      ])
    let timeline = calculator.timeline(on: mondayNoon, at: mondayNoon, data: data)

    #expect(timeline.segments.map(\.lane) == [.focus, .idle, .focus, .rest, .rest, .focus])
    #expect(timeline.total(.focus) == 1800 + 1500 + 600)
    #expect(timeline.total(.idle) == 300)
    #expect(timeline.total(.rest) == 620)
    #expect(timeline.segments.last?.interval.end == mondayNoon)
    #expect(timeline.domain == DateInterval(start: utcDate(2026, 11, 2, 8), end: utcDate(2026, 11, 2, 12)))
  }

  @Test func overnightActivityIsCutAtMidnight() {
    let late = ActivityInterval(
      sessionID: session, kind: .active, start: utcDate(2026, 11, 1, 23), end: utcDate(2026, 11, 2, 1, 30))
    let timeline = calculator.timeline(
      on: mondayNoon, at: utcDate(2026, 11, 2, 2), data: TelemetrySnapshot(activity: [late]))
    #expect(
      timeline.segments == [
        TimelineSegment(
          lane: .focus, interval: DateInterval(start: utcDate(2026, 11, 2), end: utcDate(2026, 11, 2, 1, 30)))
      ])
    #expect(timeline.domain == DateInterval(start: utcDate(2026, 11, 2), end: utcDate(2026, 11, 2, 4)))
  }

  @Test func pastDayDomainStaysInsideTheDay() {
    let evening = ActivityInterval(
      sessionID: session, kind: .active, start: utcDate(2026, 11, 1, 22), end: utcDate(2026, 11, 1, 23, 10))
    let timeline = calculator.timeline(
      on: utcDate(2026, 11, 1, 12), at: mondayNoon, data: TelemetrySnapshot(activity: [evening]))
    #expect(timeline.domain == DateInterval(start: utcDate(2026, 11, 1, 20), end: utcDate(2026, 11, 2)))
  }
}

@Suite struct HourlyHeatmapTests {
  @Test func coversEveryHourOfEachDayOldestFirst() {
    let heatmap = calculator.hourlyHeatmap(days: 7, at: mondayNoon, active: [])
    #expect(heatmap.days.count == 7)
    #expect(heatmap.days.first == utcDate(2026, 10, 27))
    #expect(heatmap.days.last == utcDate(2026, 11, 2))
    #expect(heatmap.cells.count == 7 * 24)
    #expect(heatmap.isEmpty)
    #expect(heatmap.peak == nil)
  }

  @Test func focusIsSplitAcrossHoursAndIdleIsIgnored() {
    let active = [
      activity(.active, 9, 30, minutes: 60),
      activity(.idle, 11, 0, minutes: 30),
      ActivityInterval(
        sessionID: session, kind: .active, start: utcDate(2026, 10, 20, 9), end: utcDate(2026, 10, 20, 10)),
    ]
    let heatmap = calculator.hourlyHeatmap(days: 7, at: mondayNoon, active: active)
    let monday = heatmap.cells.filter { $0.day == utcDate(2026, 11, 2) && $0.focus > 0 }
    #expect(monday.map(\.hour) == [9, 10])
    #expect(monday.map(\.focus) == [1800, 1800])
    #expect(heatmap.cells.reduce(0) { $0 + $1.focus } == 3600)
    #expect(heatmap.peak?.hour == 9)
  }

  @Test func futureFocusIsNotCounted() {
    let ahead = activity(.active, 11, 30, minutes: 60)
    let heatmap = calculator.hourlyHeatmap(days: 1, at: mondayNoon, active: [ahead])
    #expect(heatmap.cells.reduce(0) { $0 + $1.focus } == 1800)
  }

  @Test func daylightSavingDayStillMapsToClockHours() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
    let interval = ActivityInterval(
      sessionID: session, kind: .active, start: start, end: start.addingTimeInterval(3 * 3600))
    let heatmap = InsightsCalculator(calendar: calendar).hourlyHeatmap(days: 1, at: now, active: [interval])
    #expect(heatmap.cells.count == 24)
    #expect(heatmap.cells.reduce(0) { $0 + $1.focus } == 3 * 3600)
    #expect(heatmap.cells.first { $0.hour == 1 }?.focus == 7200)
  }
}
