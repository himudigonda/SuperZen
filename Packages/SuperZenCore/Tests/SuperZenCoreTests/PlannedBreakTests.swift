import Foundation
import Testing

@testable import SuperZenCore

private func lunch(
  at minute: Int = 12 * 60 + 30, weekdays: Set<Int> = [2], duration: TimeInterval = 600, id: String = "lunch"
) -> PlannedBreak {
  PlannedBreak(id: id, minuteOfDay: minute, weekdays: weekdays, duration: duration)
}

private func settings(_ planned: [PlannedBreak]) -> Settings {
  var value = quietSettings()
  value.timer.workDuration = 4 * 3600
  value.timer.shortBreakDuration = 60
  value.plannedBreaks = planned
  return value
}

private func startedBreaks(_ harness: Harness) -> [SessionEffect] {
  harness.effects.filter {
    if case .showBreak = $0 { return true }
    return false
  }
}

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private func showBreakCount(
  planned: PlannedBreak, calendar: Calendar, start: Date, hours: Int
) -> (count: Int, firstAt: Date?) {
  let engine = SessionEngine(calendar: calendar)
  var value = settings([planned])
  value.timer.workDuration = 86_400
  var transition = engine.start(settings: value, at: start)
  var now = start
  var count = 0
  var firstAt: Date?
  for _ in 0..<(hours * 120) {
    now = now.addingTimeInterval(30)
    transition = engine.reduce(transition.state, .tick(.present), at: now)
    let shown = transition.effects.filter { $0 == .showBreak(.long) }.count
    if shown > 0, firstAt == nil { firstAt = now }
    count += shown
  }
  return (count, firstAt)
}

@Suite struct PlannedBreakFiringTests {
  @Test func firesAtItsMinuteAsALongBreakWithItsOwnDuration() {
    var harness = Harness(settings: settings([lunch()]))
    harness.run(for: 1799)
    #expect(harness.phase.isFocus)
    #expect(startedBreaks(harness).isEmpty)

    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .long)
    #expect(harness.state.currentBreak?.planned == 600)
    #expect(harness.visualEffects == [.showBreak(.long), .play(.breakStart)])
    #expect(harness.state.cyclesSinceLongBreak == 0)
  }

  @Test func theBreakEndsThroughTheNormalPathAndReportsItsOutcome() {
    var harness = Harness(settings: settings([lunch(duration: 90)]))
    harness.run(for: 1800)
    harness.clearEffects()
    harness.run(for: 90)
    #expect(harness.phase.isFocus)
    #expect(harness.breakOutcomes == [BreakOutcome(kind: .long, completed: true, rested: 90, planned: 90)])
    #expect(harness.visualEffects == [.hideOverlays, .play(.breakEnd)])
  }

  @Test func doesNotFireOnOtherWeekdays() {
    var harness = Harness(settings: settings([lunch(weekdays: [1, 3, 4, 5, 6, 7])]))
    harness.run(for: 3600, step: 30)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func firesOncePerDayEvenWhenTheBreakEndsInsideTheWindow() {
    var harness = Harness(settings: settings([lunch(duration: 30)]))
    harness.run(for: 3600, step: 10)
    #expect(startedBreaks(harness) == [.showBreak(.long)])
  }

  @Test func firesAgainOnTheNextDay() {
    var harness = Harness(settings: settings([lunch(weekdays: [2, 3])]), at: utcDate(2026, 11, 3, 12))
    harness.state.plannedBreaksFired["lunch"] = utcDate(2026, 11, 2, 12, 31)
    harness.run(for: 1800)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func doesNotFireTwiceOnTheSameDay() {
    var harness = Harness(settings: settings([lunch()]), at: mondayNoon)
    harness.state.plannedBreaksFired["lunch"] = utcDate(2026, 11, 2, 12, 10)
    harness.run(for: 1900)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func eachIdFiresOnItsOwn() {
    var harness = Harness(
      settings: settings([
        lunch(at: 12 * 60 + 10, id: "a"), lunch(at: 12 * 60 + 40, duration: 60, id: "b"),
      ]))
    harness.run(for: 3000, step: 10)
    #expect(startedBreaks(harness).count == 2)
  }

  @Test func aWakeWithinFiveMinutesStillFires() {
    var harness = Harness(settings: settings([lunch()]))
    harness.run(for: 1500)
    harness.send(.suspend(.sleep))
    harness.jump(by: 540)
    harness.send(.resume(.sleep))
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func aWakeMoreThanFiveMinutesLateSkipsItForTheDay() {
    var harness = Harness(settings: settings([lunch()]))
    harness.run(for: 1500)
    harness.send(.suspend(.sleep))
    harness.jump(by: 690)
    harness.send(.resume(.sleep))
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(startedBreaks(harness).isEmpty)
    #expect(harness.state.plannedBreaksFired["lunch"] != nil)
    harness.run(for: 600, step: 30)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func neverFiresWhileUserPausedAndDoesNotCatchUpAfterwards() {
    var harness = Harness(settings: settings([lunch()]))
    harness.send(.pause(for: nil))
    harness.run(for: 1900, step: 30)
    #expect(harness.phase.pauseReason == .user)
    #expect(harness.state.plannedBreaksFired["lunch"] != nil)
    harness.send(.togglePause)
    harness.run(for: 120, step: 10)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func neverFiresDuringScheduleSleep() {
    var value = settings([lunch()])
    value.schedule.enabled = true
    value.schedule.window = TimeWindow(startMinute: 9 * 60, endMinute: 11 * 60)
    var harness = Harness(settings: value, at: utcDate(2026, 11, 2, 11, 40))
    harness.run(for: 3600, step: 30)
    #expect(harness.phase.pauseReason == .schedule)
    #expect(startedBreaks(harness).isEmpty)
    #expect(harness.state.plannedBreaksFired["lunch"] != nil)
  }

  @Test func doesNotStartABreakInsideANaturalBreakAndCountsItFired() {
    var harness = Harness(settings: settings([lunch()]), at: utcDate(2026, 11, 2, 12, 25))
    harness.runIdle(for: 360)
    #expect(harness.phase.isNaturalBreak)
    #expect(startedBreaks(harness).isEmpty)
    #expect(harness.state.plannedBreaksFired["lunch"] != nil)
    harness.run(for: 60, step: 10)
    #expect(harness.phase.isFocus)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func doesNotReplaceABreakThatIsAlreadyRunning() {
    var value = settings([lunch()])
    value.timer.shortBreakDuration = 120
    var harness = Harness(settings: value, at: utcDate(2026, 11, 2, 12, 29, 30))
    harness.send(.startBreak)
    harness.clearEffects()
    harness.run(for: 60, step: 10)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.state.currentBreak?.planned == 120)
    #expect(startedBreaks(harness).isEmpty)
    harness.run(for: 300, step: 10)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func aNudgeInProgressIsReplacedWithoutALeakedOverlay() {
    var value = settings([lunch()])
    value.timer.workDuration = 2100
    value.timer.nudgeLeadTime = 600
    var harness = Harness(settings: value)
    harness.run(for: 1500)
    #expect(harness.phase.isNudge)
    harness.clearEffects()
    harness.run(for: 300)
    #expect(harness.phase.breakKind != nil)
    #expect(harness.visualEffects.first == .hideOverlays)
  }

  @Test func theFocusRemainingBeforeThePlannedBreakIsKept() {
    var value = settings([lunch(duration: 60)])
    value.timer.resetFocusAfterBreak = false
    var harness = Harness(settings: value)
    harness.run(for: 1800)
    #expect(harness.state.currentBreak?.focusRemainingBeforeBreak == 12_600)
    harness.run(for: 60)
    #expect(harness.remaining == 12_600)
  }

  @Test func deadlineBreaksAndManualStartsKeepTheConfiguredDuration() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    #expect(harness.state.currentBreak?.planned == 20)
    harness.run(for: 20)
    harness.run(for: 1200)
    #expect(harness.state.currentBreak?.planned == 20)
  }
}

@Suite struct PlannedBreakSettingsTests {
  @Test func editingSettingsAfterItFiredDoesNotFireItAgain() {
    var value = settings([lunch(duration: 30)])
    var harness = Harness(settings: value)
    harness.run(for: 1800)
    harness.run(for: 30)
    #expect(harness.phase.isFocus)
    #expect(startedBreaks(harness).count == 1)

    value.plannedBreaks = [lunch(duration: 45)]
    harness.send(.settingsChanged(value))
    value.timer.snoozeDuration = 120
    value.plannedBreaks = [lunch(at: 12 * 60 + 29, duration: 45)]
    harness.send(.settingsChanged(value))
    harness.run(for: 600, step: 10)
    #expect(startedBreaks(harness).count == 1)
  }

  @Test func addingAnAlreadyPassedBreakDoesNotFireItRetroactively() {
    var harness = Harness(settings: settings([]), at: utcDate(2026, 11, 2, 12, 31))
    harness.send(.settingsChanged(settings([lunch()])))
    harness.run(for: 120, step: 10)
    #expect(startedBreaks(harness).isEmpty)
  }

  @Test func addingABreakForLaterTodayStillFires() {
    var harness = Harness(settings: settings([]))
    harness.send(.settingsChanged(settings([lunch()])))
    harness.run(for: 1800)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func movingABreakLaterTodayBeforeItFiredStillFiresAtTheNewTime() {
    var harness = Harness(settings: settings([lunch(at: 12 * 60 + 5)]))
    harness.send(.settingsChanged(settings([lunch(at: 12 * 60 + 20)])))
    harness.run(for: 1199)
    #expect(startedBreaks(harness).isEmpty)
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func theJSONRoundTripKeepsEveryField() {
    let list = [lunch(), lunch(at: 600, weekdays: [3, 5], duration: 120, id: "walk")]
    #expect(PlannedBreak.list(fromJSON: PlannedBreak.json(from: list)) == list)
  }
}

@Suite struct PlannedBreakDaylightSavingTests {
  @Test func springForwardDayFiresExactlyOnceForATimeThatDoesNotExist() {
    let start = newYork().date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1))!
    let result = showBreakCount(
      planned: lunch(at: 2 * 60 + 30, weekdays: Set(1...7)), calendar: newYork(), start: start, hours: 3)
    #expect(result.count == 1)
    let earliest = newYork().date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3))!
    #expect(
      result.firstAt.map { $0.isAtOrAfter(earliest) && $0.isAtOrBefore(earliest.addingTimeInterval(1800)) } == true)
  }

  @Test func fallBackDayFiresOnlyOnTheFirstOccurrenceOfTheRepeatedTime() {
    let start = newYork().date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
    let result = showBreakCount(
      planned: lunch(at: 60 + 30, weekdays: Set(1...7)), calendar: newYork(), start: start, hours: 3)
    #expect(result.count == 1)
    #expect(result.firstAt == start.addingTimeInterval(5400))
  }

  @Test func anOrdinaryDayFiresAtTheLocalMinute() {
    let start = newYork().date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
    let result = showBreakCount(
      planned: lunch(at: 12 * 60 + 30, weekdays: Set(1...7)), calendar: newYork(), start: start, hours: 1)
    #expect(result.count == 1)
    #expect(result.firstAt == start.addingTimeInterval(1800))
  }
}
