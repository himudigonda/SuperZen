import Foundation
import Testing

@testable import SuperZenCore

private func newYork() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}

private func nyDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
  newYork().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func userPause(_ harness: Harness) -> Pause? {
  if case .paused(let pause) = harness.phase, pause.reason == .user { return pause }
  return nil
}

@Suite struct TimedPauseTests {
  @Test func pausesUntilTheDeadlineThenRestoresTheFocusRemaining() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 100)
    harness.send(.pause(for: 900))
    #expect(userPause(harness)?.until == harness.now.addingTimeInterval(900))

    harness.run(for: 899)
    #expect(harness.phase.pauseReason == .user)

    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1100)
    #expect(harness.telemetry == [.focusStarted])
  }

  @Test func indefinitePauseNeverExpires() {
    var harness = Harness(settings: quietSettings())
    harness.send(.pause(for: nil))
    #expect(userPause(harness)?.until == nil)
    harness.run(for: 5000, step: 60)
    #expect(harness.phase.pauseReason == .user)
  }

  @Test func togglePauseCancelsTheTimedPause() {
    var harness = Harness(settings: quietSettings())
    harness.send(.pause(for: 900))
    harness.run(for: 30)
    harness.send(.togglePause)
    #expect(harness.phase.isFocus)
    harness.run(for: 2000, step: 30)
    #expect(harness.phase.pauseReason == nil)
  }

  @Test func aSecondRequestReplacesTheDeadline() {
    var harness = Harness(settings: quietSettings())
    harness.send(.pause(for: 300))
    harness.run(for: 100)
    harness.send(.pause(for: 600))
    #expect(userPause(harness)?.until == harness.now.addingTimeInterval(600))
    harness.run(for: 599)
    #expect(harness.phase.pauseReason == .user)
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
  }

  @Test func anIndefiniteRequestClearsTheDeadlineWithoutResuming() {
    var harness = Harness(settings: quietSettings())
    harness.send(.pause(for: 60))
    harness.run(for: 10)
    harness.send(.pause(for: nil))
    #expect(userPause(harness)?.until == nil)
    harness.run(for: 600, step: 30)
    #expect(harness.phase.pauseReason == .user)
  }

  @Test func theDurationIsClampedAndInvalidValuesAreIgnored() {
    var harness = Harness(settings: quietSettings())
    for invalid in [0, -5, .nan, .infinity, -.infinity] as [TimeInterval] {
      harness.send(.pause(for: invalid))
      #expect(harness.phase.isFocus, "\(invalid)")
    }
    harness.send(.pause(for: 0.2))
    #expect(userPause(harness)?.until == harness.now.addingTimeInterval(1))
    harness.send(.pause(for: 1e12))
    #expect(userPause(harness)?.until == harness.now.addingTimeInterval(Settings.maximumDuration))
  }

  @Test func scheduleAndSystemPausesIgnoreTheRequest() {
    var system = Harness(settings: quietSettings())
    system.send(.suspend(.sleep))
    system.send(.pause(for: 300))
    #expect(userPause(system) == nil)
    #expect(system.phase.pauseReason == .system)

    var settings = quietSettings()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 9 * 60, endMinute: 11 * 60)
    var scheduled = Harness(settings: settings)
    scheduled.run(for: 1)
    #expect(scheduled.phase.pauseReason == .schedule)
    scheduled.send(.pause(for: 300))
    scheduled.send(.pause(for: nil))
    #expect(scheduled.phase.pauseReason == .schedule)
    #expect(userPause(scheduled) == nil)
  }

  @Test func hardcoreBreakIgnoresTheRequest() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    harness.send(.pause(for: 300))
    #expect(harness.phase.breakKind != nil)
  }

  @Test func aTimedPauseDuringABreakReturnsToTheBreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.pause(for: 120))
    #expect(harness.phase.pauseReason == .user)
    harness.run(for: 119)
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.visualEffects == [.showBreak(.short)])
    #expect(harness.state.currentBreak?.remaining(at: harness.now) == 15)
  }

  @Test func wellnessDueTimesShiftByTheTimeSpentPaused() {
    var harness = Harness()
    harness.run(for: 10)
    let before = harness.state.wellnessDue
    #expect(!before.isEmpty)
    harness.send(.pause(for: 600))
    harness.run(for: 600)
    #expect(harness.phase.isFocus)
    for (kind, due) in before {
      #expect(harness.state.wellnessDue[kind] == due.addingTimeInterval(600), "\(kind)")
    }
  }

  @Test func aPauseThatExpiredDuringSleepResumesOnTheFirstTickAfterWake() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 50)
    harness.send(.pause(for: 300))
    harness.send(.suspend(.sleep))
    harness.jump(by: 1000)
    harness.send(.resume(.sleep))
    #expect(harness.phase.pauseReason == .user)

    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1150)
  }

  @Test func aPauseThatExpiredDuringALongGapResumesWithoutStallingTheEngine() {
    var harness = Harness(settings: quietSettings())
    harness.send(.pause(for: 300))
    harness.jump(by: 5000)
    harness.tick()
    #expect(harness.phase.isFocus)
    harness.run(for: 10)
    #expect(harness.phase.isFocus)
  }

  @Test func stepsBackOfTheWallClockKeepTheRemainingPauseTime() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 10)
    harness.send(.pause(for: 600))
    harness.run(for: 100)
    harness.jump(by: -3600)
    harness.tick()
    #expect(harness.phase.pauseReason == .user)
    #expect(userPause(harness)?.until == harness.now.addingTimeInterval(500))

    harness.run(for: 499)
    #expect(harness.phase.pauseReason == .user)
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
  }

  @Test func theSnapshotExposesTheDeadlineOnlyForTimedUserPauses() {
    var harness = Harness(settings: quietSettings())
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).pausedUntil == nil)
    harness.send(.pause(for: 900))
    let snapshot = MenuBarSnapshot(state: harness.state, at: harness.now)
    #expect(snapshot.pausedUntil == harness.now.addingTimeInterval(900))
    #expect(snapshot.isPaused)
    harness.send(.pause(for: nil))
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).pausedUntil == nil)
  }
}

@Suite struct PausePresetTests {
  @Test func fixedPresetsMatchTheirLabels() {
    let schedule = FocusSchedule()
    let durations = PausePreset.allCases.filter { $0 != .untilTomorrow }.map {
      $0.duration(at: mondayNoon, schedule: schedule, calendar: .utc)
    }
    #expect(durations == [900, 3600, 7200])
  }

  @Test func untilTomorrowWithoutAScheduleIsTheNextNineOClock() {
    let schedule = FocusSchedule()
    let evening = utcDate(2026, 11, 2, 19)
    #expect(PausePreset.untilTomorrow.duration(at: evening, schedule: schedule, calendar: .utc) == 14 * 3600)
    let early = utcDate(2026, 11, 2, 8)
    #expect(PausePreset.untilTomorrow.duration(at: early, schedule: schedule, calendar: .utc) == 3600)
    let exactly = utcDate(2026, 11, 2, 9)
    #expect(PausePreset.untilTomorrow.duration(at: exactly, schedule: schedule, calendar: .utc) == 86_400)
  }

  @Test func untilTomorrowWithAScheduleIsTheNextWindowStart() {
    var schedule = FocusSchedule()
    schedule.enabled = true
    schedule.window = TimeWindow(startMinute: 8 * 60 + 30, endMinute: 17 * 60)
    schedule.weekdays = [2, 3, 4, 5, 6]
    let mondayEvening = utcDate(2026, 11, 2, 19)
    #expect(PausePreset.untilTomorrow.duration(at: mondayEvening, schedule: schedule, calendar: .utc) == 13.5 * 3600)
    let fridayEvening = utcDate(2026, 11, 6, 19)
    #expect(
      PausePreset.untilTomorrow.duration(at: fridayEvening, schedule: schedule, calendar: .utc) == (61.5) * 3600)
  }

  @Test func aScheduleWithoutWeekdaysFallsBackToNineOClock() {
    var schedule = FocusSchedule()
    schedule.enabled = true
    schedule.weekdays = []
    let evening = utcDate(2026, 11, 2, 19)
    #expect(PausePreset.untilTomorrow.duration(at: evening, schedule: schedule, calendar: .utc) == 14 * 3600)
  }

  @Test func untilTomorrowCountsRealSecondsAcrossDaylightSavingChanges() {
    let schedule = FocusSchedule()
    let fallBack = PausePreset.untilTomorrow.duration(
      at: nyDate(2026, 10, 31, 20), schedule: schedule, calendar: newYork())
    #expect(fallBack == 14 * 3600)
    let springForward = PausePreset.untilTomorrow.duration(
      at: nyDate(2026, 3, 7, 20), schedule: schedule, calendar: newYork())
    #expect(springForward == 12 * 3600)
  }
}
