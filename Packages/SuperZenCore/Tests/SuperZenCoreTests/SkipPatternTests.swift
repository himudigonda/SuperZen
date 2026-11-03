import Foundation
import Testing

@testable import SuperZenCore

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private func record(_ result: BreakResult, at start: Date) -> BreakRecord {
  BreakRecord(kind: .short, result: result, start: start, end: start.addingTimeInterval(20), planned: 20)
}

private func records(_ result: BreakResult, count: Int, hour: Int, day: Int = 2) -> [BreakRecord] {
  (0..<count).map { index in
    record(result, at: utcDate(2026, 11, day, hour, index))
  }
}

private func analyze(_ breaks: [BreakRecord], calendar: Calendar = .utc) -> SkipPattern {
  SkipPattern.analyze(breaks, calendar: calendar)
}

@Suite struct SkipPatternTests {
  @Test func noRecordsMeansInsufficientData() {
    let pattern = analyze([])
    #expect(pattern.hours.isEmpty)
    #expect(pattern.worst == nil)
    #expect(pattern.advice == .insufficientData)
  }

  @Test func fourBreaksInAnHourAreNotEnoughButFiveAre() {
    let four = records(.skipped, count: 4, hour: 9)
    #expect(analyze(four).advice == .insufficientData)
    #expect(analyze(four).worst == nil)

    let five = records(.skipped, count: 5, hour: 9)
    #expect(analyze(five).worst == HourSkipStats(hour: 9, total: 5, skipped: 5))
    #expect(analyze(five).advice == .plannedBreak(hour: 9, skipRate: 1))
  }

  @Test func samplesAreNotPooledAcrossHours() {
    let spread = (8..<18).flatMap { records(.skipped, count: 2, hour: $0) }
    #expect(analyze(spread).advice == .insufficientData)
  }

  @Test func worstHourHasTheHighestSkipRate() {
    let breaks =
      records(.completed, count: 3, hour: 9) + records(.skipped, count: 2, hour: 9)
      + records(.completed, count: 1, hour: 14) + records(.skipped, count: 5, hour: 14)
      + records(.completed, count: 6, hour: 16)
    let pattern = analyze(breaks)
    #expect(pattern.hours.map(\.hour) == [9, 14, 16])
    #expect(pattern.worst == HourSkipStats(hour: 14, total: 6, skipped: 5))
    #expect(pattern.advice == .plannedBreak(hour: 14, skipRate: 5.0 / 6.0))
  }

  @Test func rateBelowTheThresholdGivesNoPattern() {
    let breaks = records(.completed, count: 3, hour: 11) + records(.skipped, count: 2, hour: 11)
    let pattern = analyze(breaks)
    #expect(pattern.worst?.hour == 11)
    #expect(pattern.advice == .noPattern)
  }

  @Test func rateExactlyAtTheThresholdGivesAdvice() {
    let breaks = records(.completed, count: 5, hour: 11) + records(.skipped, count: 5, hour: 11)
    #expect(analyze(breaks).advice == .plannedBreak(hour: 11, skipRate: 0.5))
  }

  @Test func neverSkippingGivesNoPattern() {
    let pattern = analyze(records(.completed, count: 8, hour: 10))
    #expect(pattern.worst == HourSkipStats(hour: 10, total: 8, skipped: 0))
    #expect(pattern.advice == .noPattern)
  }

  @Test func naturalBreaksCountAsTakenNotSkipped() {
    let breaks = records(.natural, count: 3, hour: 13) + records(.skipped, count: 2, hour: 13)
    #expect(analyze(breaks).worst == HourSkipStats(hour: 13, total: 5, skipped: 2))
  }

  @Test func equalRatesPreferTheLargerSampleThenTheEarlierHour() {
    let larger =
      records(.skipped, count: 5, hour: 9) + records(.skipped, count: 6, hour: 15)
    #expect(analyze(larger).worst?.hour == 15)
    let equal = records(.skipped, count: 5, hour: 15) + records(.skipped, count: 5, hour: 9)
    #expect(analyze(equal).worst?.hour == 9)
  }

  @Test func hoursFollowTheInjectedCalendar() {
    let breaks = records(.skipped, count: 5, hour: 23)
    #expect(analyze(breaks, calendar: .utc).worst?.hour == 23)
    #expect(analyze(breaks, calendar: newYork()).worst?.hour == 18)
  }

  @Test func recordsAreBucketedByTheirStartHour() {
    let straddling = (0..<5).map { index in
      BreakRecord(
        kind: .long, result: .skipped, start: utcDate(2026, 11, 2, 9, 55 + index % 5),
        end: utcDate(2026, 11, 2, 10, 5), planned: 600)
    }
    #expect(analyze(straddling).worst?.hour == 9)
  }

  @Test func minimumBelowOneStillRequiresASample() {
    let pattern = SkipPattern.analyze([], calendar: .utc, minimumPerHour: 0)
    #expect(pattern.advice == .insufficientData)
    let single = SkipPattern.analyze(records(.skipped, count: 1, hour: 9), calendar: .utc, minimumPerHour: 0)
    #expect(single.worst?.total == 1)
  }

  @Test func fallBackDayCountsEachBreakOnceInTheRepeatedHour() {
    let calendar = newYork()
    let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    let firstOneThirty = midnight.addingTimeInterval(3600 + 1800)
    let secondOneThirty = midnight.addingTimeInterval(2 * 3600 + 1800)
    #expect(calendar.component(.hour, from: firstOneThirty) == 1)
    #expect(calendar.component(.hour, from: secondOneThirty) == 1)

    let breaks =
      (0..<3).map { record(.skipped, at: firstOneThirty.addingTimeInterval(Double($0) * 60)) }
      + (0..<4).map { record(.completed, at: secondOneThirty.addingTimeInterval(Double($0) * 60)) }
    let pattern = analyze(breaks, calendar: calendar)
    #expect(pattern.hours == [HourSkipStats(hour: 1, total: 7, skipped: 3)])
  }

  @Test func springForwardDayHasNoPhantomHour() {
    let calendar = newYork()
    let midnight = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
    let before = midnight.addingTimeInterval(3600 + 1800)
    let after = midnight.addingTimeInterval(2 * 3600 + 1800)
    #expect(calendar.component(.hour, from: before) == 1)
    #expect(calendar.component(.hour, from: after) == 3)

    let breaks =
      (0..<5).map { record(.skipped, at: before.addingTimeInterval(Double($0) * 60)) }
      + (0..<5).map { record(.skipped, at: after.addingTimeInterval(Double($0) * 60)) }
    let pattern = analyze(breaks, calendar: calendar)
    #expect(pattern.hours.map(\.hour) == [1, 3])
    #expect(pattern.hours.map(\.total) == [5, 5])
  }

  @Test func midnightBoundaryRecordsLandInHourZero() {
    let calendar = newYork()
    let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
    let breaks = (0..<5).map { record(.skipped, at: midnight.addingTimeInterval(Double($0))) }
    #expect(analyze(breaks, calendar: calendar).worst?.hour == 0)
  }

  @Test func inputOrderDoesNotMatter() {
    let breaks =
      records(.completed, count: 3, hour: 9) + records(.skipped, count: 3, hour: 9)
      + records(.skipped, count: 5, hour: 20)
    #expect(analyze(breaks) == analyze(breaks.reversed()))
  }
}
