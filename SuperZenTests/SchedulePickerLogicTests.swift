import AppKit
import Foundation
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
struct SchedulePickerLogicTests {
  @Test func timeFormatFollowsTheLocale() {
    let us = ZenTimeFormat.string(minuteOfDay: 9 * 60, locale: Locale(identifier: "en_US"))
    let british = ZenTimeFormat.string(minuteOfDay: 9 * 60, locale: Locale(identifier: "en_GB"))
    let germanEvening = ZenTimeFormat.string(
      minuteOfDay: 22 * 60 + 30, locale: Locale(identifier: "de_DE"))
    #expect(us.hasPrefix("9:00"))
    #expect(us.contains("AM"))
    #expect(british.hasSuffix("9:00"))
    #expect(!british.contains("AM"))
    #expect(germanEvening == "22:30")
  }

  @Test func timeFormatClampsOutOfRangeMinutes() {
    let locale = Locale(identifier: "en_GB")
    #expect(
      ZenTimeFormat.string(minuteOfDay: -30, locale: locale)
        == ZenTimeFormat.string(minuteOfDay: 0, locale: locale))
    #expect(ZenTimeFormat.string(minuteOfDay: 5000, locale: locale) == "23:59")
  }

  @Test func timeOptionsIncludeOffGridValuesOnce() {
    let options = ZenTimeFormat.options(stepMinutes: 30, including: [545, 540])
    #expect(options.first == 0)
    #expect(options.last == 1410)
    #expect(options.contains(545))
    #expect(options.filter { $0 == 540 }.count == 1)
    #expect(options == options.sorted())
  }

  @Test func sameDayRangesRejectEmptyAndBackwardRanges() {
    #expect(TimeRangeRule.sameDay.issue(start: 540, end: 1080) == nil)
    #expect(TimeRangeRule.sameDay.issue(start: 540, end: 540) == .empty)
    #expect(TimeRangeRule.sameDay.issue(start: 1080, end: 540) == .endBeforeStart)
  }

  @Test func overnightRangesAcceptWrappingButNotEmpty() {
    #expect(TimeRangeRule.allowsOvernight.issue(start: 1320, end: 420) == nil)
    #expect(TimeRangeRule.allowsOvernight.issue(start: 600, end: 600) == .empty)
  }

  @Test func movingStartPastEndPicksTheNextValidEnd() {
    let options = ZenTimeFormat.options(stepMinutes: 30)
    #expect(TimeRangeRule.sameDay.adjustedEnd(start: 1200, end: 1080, options: options) == 1230)
    #expect(TimeRangeRule.sameDay.adjustedEnd(start: 540, end: 1080, options: options) == 1080)
    #expect(TimeRangeRule.allowsOvernight.adjustedEnd(start: 600, end: 600, options: options) == 630)
    #expect(TimeRangeRule.sameDay.isSelectableStart(1410, options: options) == false)
    #expect(TimeRangeRule.allowsOvernight.isSelectableStart(1410, options: options))
  }

  @Test func weekdaysFollowTheCalendarsFirstWeekday() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = 1
    #expect(WeekdayOrder.symbols(for: calendar).map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
    calendar.firstWeekday = 2
    let mondayFirst = WeekdayOrder.symbols(for: calendar)
    #expect(mondayFirst.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
    #expect(mondayFirst.first?.fullName == "Monday")
  }

  @Test func weekdayNamesAreLocalized() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "de_DE")
    calendar.firstWeekday = 2
    let symbols = WeekdayOrder.symbols(for: calendar)
    #expect(symbols.first?.fullName == "Montag")
    #expect(symbols.count == 7)
    #expect(symbols.allSatisfy { !$0.shortLabel.isEmpty })
  }

  @Test func togglingKeepsAtLeastOneWeekday() {
    #expect(WeekdayOrder.toggling(3, in: [2, 3]) == [2])
    #expect(WeekdayOrder.toggling(4, in: [2]) == [2, 4])
    #expect(WeekdayOrder.toggling(2, in: [2]) == [2])
    #expect(WeekdayOrder.toggling(9, in: [2]) == [2])
  }
}
