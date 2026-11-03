import Foundation
import Testing

@testable import SuperZenCore

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private func overnight(weekdays: Set<Int> = [2, 3, 4, 5, 6]) -> FocusSchedule {
  var schedule = FocusSchedule()
  schedule.enabled = true
  schedule.window = TimeWindow(startMinute: 22 * 60, endMinute: 6 * 60)
  schedule.weekdays = weekdays
  return schedule
}

@Suite struct ScheduleEdgeTests {
  @Test(
    arguments: [
      (utcDate(2026, 11, 2, 23, 0), true),
      (utcDate(2026, 11, 3, 3, 0), true),
      (utcDate(2026, 11, 6, 23, 30), true),
      (utcDate(2026, 11, 7, 0, 0), true),
      (utcDate(2026, 11, 7, 5, 59), true),
      (utcDate(2026, 11, 7, 6, 0), false),
      (utcDate(2026, 11, 7, 23, 0), false),
      (utcDate(2026, 11, 8, 3, 0), false),
      (utcDate(2026, 11, 9, 3, 0), false),
      (utcDate(2026, 11, 9, 22, 0), true),
      (utcDate(2026, 11, 9, 21, 59), false),
    ] as [(Date, Bool)])
  func overnightWindowBelongsToTheWeekdayItStartedOn(moment: Date, expected: Bool) {
    #expect(SchedulePolicy.isWithinSchedule(overnight(), at: moment, calendar: .utc) == expected)
  }

  @Test func equalStartAndEndCoversTheWholeOfEachSelectedDay() {
    var schedule = FocusSchedule()
    schedule.enabled = true
    schedule.window = TimeWindow(startMinute: 600, endMinute: 600)
    schedule.weekdays = [2]
    #expect(SchedulePolicy.isWithinSchedule(schedule, at: utcDate(2026, 11, 2, 0, 0), calendar: .utc))
    #expect(SchedulePolicy.isWithinSchedule(schedule, at: utcDate(2026, 11, 2, 23, 59), calendar: .utc))
    #expect(!SchedulePolicy.isWithinSchedule(schedule, at: utcDate(2026, 11, 3, 12, 0), calendar: .utc))
  }

  @Test func emptyWeekdaysNeverMatch() {
    var schedule = overnight(weekdays: [])
    #expect(!SchedulePolicy.isWithinSchedule(schedule, at: mondayNoon, calendar: .utc))
    schedule.window = TimeWindow(startMinute: 0, endMinute: 0)
    #expect(!SchedulePolicy.isWithinSchedule(schedule, at: mondayNoon, calendar: .utc))
  }

  @Test func disabledScheduleIsAlwaysWithin() {
    var schedule = overnight(weekdays: [])
    schedule.enabled = false
    #expect(SchedulePolicy.isWithinSchedule(schedule, at: mondayNoon, calendar: .utc))
  }

  @Test func windowEndIsExclusiveAndStartInclusive() {
    let window = TimeWindow(startMinute: 540, endMinute: 1080)
    #expect(window.contains(minuteOfDay: 540))
    #expect(!window.contains(minuteOfDay: 1080))
    #expect(window.contains(minuteOfDay: 1079))
    #expect(!window.contains(minuteOfDay: 539))
  }

  @Test func windowContainsClampsOutOfRangeMinutes() {
    let window = TimeWindow(startMinute: 0, endMinute: 100)
    #expect(window.contains(minuteOfDay: -50))
    #expect(!window.contains(minuteOfDay: 99_999))
  }

  @Test func weekdayCSVRoundTripsAndDropsJunk() {
    #expect(SchedulePolicy.weekdaySet(from: " 2, 3 ,x,,99,-1,7,2") == [2, 3, 7])
    #expect(SchedulePolicy.weekdaySet(from: "").isEmpty)
    #expect(SchedulePolicy.weekdaySet(from: "99999999999999999999,3") == [3])
    #expect(SchedulePolicy.weekdayCSV(from: [7, 2]) == "2,7")
  }

  @Test func minuteOfDayFollowsLocalTimeOnTransitionDays() {
    let calendar = newYork()
    let afterSpring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 5))!
    #expect(SchedulePolicy.minuteOfDay(afterSpring, calendar: calendar) == 185)
    let beforeFall = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30))!
    let repeated = beforeFall.addingTimeInterval(3600)
    #expect(SchedulePolicy.minuteOfDay(repeated, calendar: calendar) == 90)
    #expect(SchedulePolicy.minuteOfDay(repeated.addingTimeInterval(3600), calendar: calendar) == 90)
  }

  @Test func overnightProgressOnSpringForwardNightStaysBounded() {
    let calendar = newYork()
    let window = TimeWindow(startMinute: 22 * 60, endMinute: 6 * 60)
    let night = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 4))!
    let progress = DayProgress.compute(window: window, at: night, calendar: calendar)
    #expect((0...1).contains(progress.fraction))
    #expect(progress.elapsed >= 0 && progress.remaining >= 0)
    #expect(abs(progress.elapsed + progress.remaining - 7 * 3600) < 1, "\(progress)")
  }

  @Test func overnightProgressOnFallBackNightStaysBounded() {
    let calendar = newYork()
    let window = TimeWindow(startMinute: 22 * 60, endMinute: 6 * 60)
    let night = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 4))!
    let progress = DayProgress.compute(window: window, at: night, calendar: calendar)
    #expect(abs(progress.elapsed + progress.remaining - 9 * 3600) < 1, "\(progress)")
  }

  @Test func windowStartingInTheSkippedHourStillProducesAShift() {
    let calendar = newYork()
    let window = TimeWindow(startMinute: 2 * 60 + 30, endMinute: 5 * 60)
    let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 4))!
    let progress = DayProgress.compute(window: window, at: morning, calendar: calendar)
    #expect(progress.elapsed > 0 && progress.remaining > 0, "\(progress)")
  }

  @Test func quietHoursAcrossMidnightSuppressBothSides() {
    var quiet = QuietHours()
    quiet.enabled = true
    quiet.window = TimeWindow(startMinute: 1320, endMinute: 420)
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 2, 23, 59), calendar: .utc))
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 3, 0, 0), calendar: .utc))
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 3, 6, 59), calendar: .utc))
    #expect(!SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 3, 7, 0), calendar: .utc))
    quiet.enabled = false
    #expect(!SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 3, 1, 0), calendar: .utc))
  }

  @Test func equalQuietHoursSuppressAllDay() {
    var quiet = QuietHours()
    quiet.enabled = true
    quiet.window = TimeWindow(startMinute: 300, endMinute: 300)
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 3, 13, 0), calendar: .utc))
  }
}
