import Foundation
import Testing

@testable import SuperZenCore

@Suite struct SchedulePolicyTests {
  private func schedule(_ start: Int, _ end: Int, weekdays: Set<Int> = [2, 3, 4, 5, 6]) -> FocusSchedule {
    var schedule = FocusSchedule()
    schedule.enabled = true
    schedule.window = TimeWindow(startMinute: start, endMinute: end)
    schedule.weekdays = weekdays
    return schedule
  }

  @Test func weekdayParsingDropsJunk() {
    #expect(SchedulePolicy.weekdaySet(from: "2, 3,x,9,") == [2, 3])
    #expect(SchedulePolicy.weekdayCSV(from: [6, 2, 4]) == "2,4,6")
  }

  @Test func windowIncludesStartAndExcludesEnd() {
    let workday = schedule(540, 1080)
    #expect(SchedulePolicy.isWithinSchedule(workday, at: utcDate(2026, 11, 2, 9), calendar: .utc))
    #expect(!SchedulePolicy.isWithinSchedule(workday, at: utcDate(2026, 11, 2, 18), calendar: .utc))
    #expect(!SchedulePolicy.isWithinSchedule(workday, at: utcDate(2026, 11, 7, 12), calendar: .utc))
  }

  @Test func disabledScheduleIsAlwaysOn() {
    var off = schedule(540, 1080)
    off.enabled = false
    #expect(SchedulePolicy.isWithinSchedule(off, at: utcDate(2026, 11, 7, 3), calendar: .utc))
  }

  @Test func overnightShiftBelongsToTheDayItStarted() {
    let fridayNight = schedule(1320, 120, weekdays: [6])
    #expect(SchedulePolicy.isWithinSchedule(fridayNight, at: utcDate(2026, 11, 6, 23), calendar: .utc))
    #expect(SchedulePolicy.isWithinSchedule(fridayNight, at: utcDate(2026, 11, 7, 1), calendar: .utc))
    #expect(!SchedulePolicy.isWithinSchedule(fridayNight, at: utcDate(2026, 11, 6, 1), calendar: .utc))
    #expect(!SchedulePolicy.isWithinSchedule(fridayNight, at: utcDate(2026, 11, 7, 23), calendar: .utc))
  }

  @Test func quietHoursWrapMidnight() {
    var quiet = QuietHours()
    quiet.enabled = true
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 2, 23), calendar: .utc))
    #expect(SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 2, 6, 59), calendar: .utc))
    #expect(!SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 2, 7), calendar: .utc))
    quiet.enabled = false
    #expect(!SchedulePolicy.isWithinQuietHours(quiet, at: utcDate(2026, 11, 2, 23), calendar: .utc))
  }
}

@Suite struct DayProgressTests {
  @Test func sameDayWindowMidpoint() {
    let progress = DayProgress.compute(
      window: TimeWindow(startMinute: 540, endMinute: 1020), at: utcDate(2026, 11, 2, 13), calendar: .utc)
    #expect(progress == DayProgress(fraction: 0.5, elapsed: 14400, remaining: 14400))
  }

  @Test func beforeStartIsZeroAndAfterEndIsFull() {
    let window = TimeWindow(startMinute: 540, endMinute: 1020)
    #expect(DayProgress.compute(window: window, at: utcDate(2026, 11, 2, 8), calendar: .utc) == .zero)
    let after = DayProgress.compute(window: window, at: utcDate(2026, 11, 2, 18), calendar: .utc)
    #expect(after == DayProgress(fraction: 1, elapsed: 28800, remaining: 0))
  }

  @Test func overnightWindowTracksBothSidesOfMidnight() {
    let window = TimeWindow(startMinute: 1320, endMinute: 360)
    let evening = DayProgress.compute(window: window, at: utcDate(2026, 11, 2, 23), calendar: .utc)
    #expect(evening.fraction == 0.125)
    let morning = DayProgress.compute(window: window, at: utcDate(2026, 11, 3, 2), calendar: .utc)
    #expect(morning == DayProgress(fraction: 0.5, elapsed: 14400, remaining: 14400))
    #expect(DayProgress.compute(window: window, at: utcDate(2026, 11, 3, 12), calendar: .utc) == .zero)
  }

  @Test func emptyWindowIsZero() {
    let window = TimeWindow(startMinute: 600, endMinute: 600)
    #expect(DayProgress.compute(window: window, at: utcDate(2026, 11, 2, 12), calendar: .utc) == .zero)
  }

  @Test func daylightSavingDayUsesRealElapsedTime() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let window = TimeWindow(startMinute: 0, endMinute: 1439)
    let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
    let progress = DayProgress.compute(window: window, at: noon, calendar: calendar)
    #expect(progress.elapsed == 13 * 3600)
  }
}
