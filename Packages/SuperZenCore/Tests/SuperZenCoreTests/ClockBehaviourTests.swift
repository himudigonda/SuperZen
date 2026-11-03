import Foundation
import Testing

@testable import SuperZenCore

private func activeSeconds(_ harness: Harness) -> TimeInterval {
  harness.telemetry.reduce(0) {
    if case .activeTime(let seconds) = $1 { return $0 + seconds }
    return $0
  }
}

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

@Suite struct ClockBehaviourTests {
  @Test func clockSteppedBackDuringFocusDoesNotExtendTheBlock() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600)
    harness.jump(by: -3600)
    harness.tick()
    let planned = harness.state.settings.timer.workDuration
    #expect(harness.remaining <= planned, "remaining \(harness.remaining)")
  }

  @Test func clockSteppedBackDuringFocusKeepsTheRemainingTime() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600)
    let before = harness.remaining
    harness.jump(by: -3600)
    harness.tick()
    #expect(abs(harness.remaining - before) < 1, "before \(before) after \(harness.remaining)")
  }

  @Test func clockSteppedBackDuringBreakDoesNotExtendTheBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1200)
    #expect(harness.phase.breakKind == .short)
    harness.run(for: 5)
    harness.jump(by: -3600)
    harness.tick()
    #expect(harness.remaining <= 20, "remaining \(harness.remaining)")
  }

  @Test func clockSteppedBackDuringPauseKeepsTheResumePoint() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.send(.togglePause)
    harness.jump(by: -7200)
    harness.send(.togglePause)
    #expect(harness.remaining <= 1200)
    #expect(harness.remaining >= 899, "remaining \(harness.remaining)")
  }

  @Test func clockSteppedBackDoesNotMoveWellnessIntoThePast() {
    var settings = quietSettings()
    settings.wellness.blink = Reminder(enabled: true, interval: 600)
    var harness = Harness(settings: settings)
    harness.run(for: 300)
    harness.jump(by: -3600)
    harness.clearEffects()
    harness.run(for: 200)
    #expect(harness.visualEffects.allSatisfy { if case .showWellness = $0 { return false } else { return true } })
  }

  @Test func duplicateTickAddsNoTelemetry() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 10)
    harness.clearEffects()
    harness.tick()
    harness.tick()
    #expect(harness.effects.isEmpty, "effects \(harness.effects)")
  }

  @Test func tickGapNeverCreditsActiveTimeForTheGap() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 60)
    let before = activeSeconds(harness)
    harness.jump(by: 5 * 3600)
    harness.tick()
    #expect(activeSeconds(harness) == before)
  }

  @Test func ticksWhileSuspendedCreditNothing() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 60)
    harness.send(.suspend(.sleep))
    harness.clearEffects()
    harness.run(for: 120)
    #expect(activeSeconds(harness) == 0)
    #expect(harness.telemetry.isEmpty)
  }

  @Test func nestedSuspensionsResumeOnlyWhenAllCausesClear() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 60)
    harness.send(.suspend(.screenLock))
    harness.send(.suspend(.sleep))
    harness.send(.suspend(.sleep))
    harness.jump(by: 30)
    harness.send(.resume(.sleep))
    #expect(harness.phase.pauseReason == .system)
    harness.send(.resume(.sleep))
    #expect(harness.phase.pauseReason == .system)
    harness.send(.resume(.screenLock))
    #expect(harness.phase.isFocus)
    #expect(harness.state.suspensions.isEmpty)
  }

  @Test func unbalancedResumeIsHarmless() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 60)
    let before = harness.state
    harness.send(.resume(.sleep))
    harness.send(.resume(.sessionSwitch))
    #expect(harness.phase == before.phase)
    #expect(harness.state.suspensions.isEmpty)
    harness.send(.suspend(.sleep))
    harness.send(.resume(.sleep))
    harness.send(.resume(.sleep))
    #expect(harness.phase.isFocus)
  }

  @Test func sleepAcrossMidnightResumesWithoutDoubleCounting() {
    var harness = Harness(settings: quietSettings(), at: utcDate(2026, 11, 2, 23, 50))
    harness.run(for: 120)
    harness.send(.suspend(.sleep))
    harness.jump(by: 8 * 3600)
    harness.clearEffects()
    harness.send(.resume(.sleep))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.telemetry.contains { if case .naturalBreak = $0 { return true } else { return false } })
  }

  @Test func suspendedThroughTheWholeNightWithScheduleResumesAsleepOrFocused() {
    var settings = quietSettings()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 540, endMinute: 1080)
    settings.schedule.weekdays = [2, 3, 4, 5, 6]
    var harness = Harness(settings: settings, at: utcDate(2026, 11, 2, 17, 50))
    harness.run(for: 60)
    harness.send(.suspend(.sleep))
    harness.jump(by: 5 * 3600)
    harness.send(.resume(.sleep))
    harness.tick()
    #expect(harness.phase.pauseReason == .schedule)
    harness.jump(by: 16 * 3600)
    harness.tick()
    #expect(harness.phase.isFocus)
  }

  @Test func scheduleFollowsLocalWallClockAcrossSpringForward() {
    var settings = quietSettings()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 9 * 60, endMinute: 17 * 60)
    settings.schedule.weekdays = [1]
    let calendar = newYork()
    let engine = SessionEngine(calendar: calendar)
    let before = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 8, minute: 59))!
    let after = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 9, minute: 1))!
    let transition = engine.start(settings: settings, at: before)
    let ticked = engine.reduce(transition.state, .tick(.present), at: before.addingTimeInterval(30))
    #expect(ticked.state.phase.pauseReason == .schedule)
    let woke = engine.reduce(ticked.state, .tick(.present), at: after)
    #expect(woke.state.phase.isFocus)
    #expect(after.timeIntervalSince(before) == 120)
  }

  @Test func scheduleFollowsLocalWallClockAcrossFallBack() {
    var settings = quietSettings()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 60, endMinute: 180)
    settings.schedule.weekdays = [1]
    let calendar = newYork()
    let engine = SessionEngine(calendar: calendar)
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 59))!
    var state = engine.start(settings: settings, at: start).state
    var now = start
    var awake: [Bool] = []
    for _ in 0..<(4 * 3600 / 30) {
      now = now.addingTimeInterval(30)
      state = engine.reduce(state, .tick(.present), at: now).state
      awake.append(!state.isScheduleSleeping)
    }
    let awakeSeconds = awake.filter { $0 }.count * 30
    #expect(awakeSeconds == 3 * 3600, "awake for \(awakeSeconds)s")
  }

  @Test func quietWindowHoldsAcrossTheRepeatedFallBackHour() {
    var settings = quietSettings()
    settings.wellness.blink = Reminder(enabled: true, interval: 600)
    settings.quietHours.enabled = true
    settings.quietHours.window = TimeWindow(startMinute: 60, endMinute: 120)
    let calendar = newYork()
    let engine = SessionEngine(calendar: calendar)
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30))!
    var state = engine.start(settings: settings, at: start).state
    var shown = 0
    var now = start
    for _ in 0..<(3 * 3600 / 30) {
      now = now.addingTimeInterval(30)
      let transition = engine.reduce(state, .tick(.present), at: now)
      state = transition.state
      if calendar.component(.hour, from: now) == 1 {
        shown += transition.effects.filter { if case .showWellness = $0 { return true } else { return false } }.count
      }
    }
    #expect(shown == 0)
  }
}
