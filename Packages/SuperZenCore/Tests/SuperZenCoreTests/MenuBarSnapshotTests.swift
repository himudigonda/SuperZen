import Foundation
import Testing

@testable import SuperZenCore

@Suite struct MenuBarSnapshotTests {
  private func snapshot(_ harness: Harness) -> MenuBarSnapshot {
    MenuBarSnapshot(state: harness.state, at: harness.now)
  }

  @Test func focusReportsProgressAndNextBreakTime() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    let menu = snapshot(harness)
    #expect(menu.glyph == .focusing)
    #expect(menu.remaining == 900)
    #expect(menu.progress == 0.25)
    #expect(menu.nextBreakAt == harness.now.addingTimeInterval(900))
    #expect(menu.nextBreakKind == .short)
    #expect(menu.isPaused == false)
    #expect(menu.isOnBreak == false)
  }

  @Test func nudgeAndTypingHaveDistinctGlyphs() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1195)
    #expect(snapshot(harness).glyph == .breakSoon)
    harness.run(for: 1, activity: .typing)
    #expect(snapshot(harness).glyph == .typing)
  }

  @Test func breakProgressCountsUpAndHidesNextBreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    let menu = snapshot(harness)
    #expect(menu.glyph == .shortBreak)
    #expect(menu.currentBreakKind == .short)
    #expect(menu.progress == 0.25)
    #expect(menu.nextBreakAt == nil)
    #expect(menu.isOnBreak)
  }

  @Test func fourthBreakIsLong() {
    var harness = Harness(settings: quietSettings())
    for _ in 0..<3 {
      harness.send(.startBreak)
      harness.run(for: 21)
    }
    #expect(snapshot(harness).nextBreakKind == .long)
    harness.send(.startBreak)
    #expect(snapshot(harness).glyph == .longBreak)
  }

  @Test func pauseFreezesProgressAndShowsPausedGlyph() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600)
    harness.send(.togglePause)
    harness.jump(by: 3600)
    let menu = snapshot(harness)
    #expect(menu.glyph == .paused)
    #expect(menu.isPaused)
    #expect(menu.progress == 0.5)
    #expect(menu.nextBreakAt == nil)
  }

  @Test func everyGlyphIsDistinct() {
    #expect(Set(MenuBarGlyph.allCases.map(\.rawValue)).count == MenuBarGlyph.allCases.count)
  }

  @Test func fractionGuardsBadInput() {
    #expect(MenuBarSnapshot.fraction(5, of: 0) == 0)
    #expect(MenuBarSnapshot.fraction(.infinity, of: 10) == 0)
    #expect(MenuBarSnapshot.fraction(20, of: 10) == 1)
    #expect(MenuBarSnapshot.fraction(-3, of: 10) == 0)
  }
}

@Suite struct MenuBarActionsTests {
  private func actions(_ harness: Harness) -> MenuBarActions {
    MenuBarActions(state: harness.state, at: harness.now)
  }

  @Test func focusAllowsOnlyStartingABreak() {
    let harness = Harness(settings: quietSettings())
    #expect(actions(harness) == MenuBarActions(canStartBreak: true, canSkip: false, canSnooze: false, skipUnlocksIn: 0))
  }

  @Test func nudgeAllowsSnoozeAndSkip() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1195)
    #expect(
      actions(harness)
        == MenuBarActions(
          canStartBreak: true, canSkip: true, canSnooze: true, skipUnlocksIn: 0, canPostpone: true))
  }

  @Test func balancedBreakCountsDownUntilSkipUnlocks() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 3)
    #expect(
      actions(harness) == MenuBarActions(canStartBreak: false, canSkip: false, canSnooze: false, skipUnlocksIn: 7))
    harness.run(for: 7)
    #expect(actions(harness).canSkip)
  }

  @Test func hardcoreNeverOffersSkip() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = Harness(settings: settings)
    harness.run(for: 1195)
    #expect(actions(harness).canSkip == false)
    harness.send(.startBreak)
    #expect(actions(harness) == MenuBarActions.none)
  }

  @Test func pausedAllowsStartingABreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.togglePause)
    #expect(actions(harness).canStartBreak)
    #expect(actions(harness).canSnooze == false)
  }
}

@Suite struct TimerStyleTests {
  @Test func clockStyleShowsMinutesAndSeconds() {
    #expect(TimerStyle.clock.format(911) == "15:11")
    #expect(TimerStyle.clock.format(0.4) == "0:01")
    #expect(TimerStyle.clock.format(-5) == "0:00")
  }

  @Test func minuteStylesRoundUpSoTheLastMinuteIsNotZero() {
    #expect(TimerStyle.minutes.format(59) == "1m")
    #expect(TimerStyle.minutes.format(60) == "1m")
    #expect(TimerStyle.minutes.format(61) == "2m")
    #expect(TimerStyle.bare.format(900) == "15")
    #expect(TimerStyle.bare.format(0) == "0")
  }

  @Test func rawValuesMatchStoredTokens() {
    #expect(TimerStyle.allCases.map(\.rawValue) == ["15:11", "15m", "15"])
  }
}

@Suite struct DayProgressMetricTests {
  private let progress = DayProgress(fraction: 0.335, elapsed: 3 * 3600 + 15 * 60, remaining: 6 * 3600 + 45 * 60 - 30)

  @Test func minutesLeftCountsWholeRemainingTime() {
    #expect(DayProgressMetric.minutesRemaining.label(for: progress) == "405m")
  }

  @Test func percentagesAddUpToOneHundred() {
    #expect(DayProgressMetric.percentDone.label(for: progress) == "33%")
    #expect(DayProgressMetric.percentRemaining.label(for: progress) == "67%")
  }

  @Test func elapsedAndHourMetrics() {
    #expect(DayProgressMetric.minutesElapsed.label(for: progress) == "195m")
    #expect(DayProgressMetric.hoursElapsed.label(for: progress) == "3h")
    #expect(DayProgressMetric.hoursRemaining.label(for: progress) == "6h")
    #expect(DayProgressMetric.timeElapsed.label(for: progress) == "3h 15m")
    #expect(DayProgressMetric.timeRemaining.label(for: progress) == "6h 45m")
  }

  @Test func shortAndRoundDurations() {
    let nearEnd = DayProgress(fraction: 0.99, elapsed: 3600, remaining: 20)
    #expect(DayProgressMetric.minutesRemaining.label(for: nearEnd) == "1m")
    #expect(DayProgressMetric.timeElapsed.label(for: nearEnd) == "1h")
    #expect(DayProgressMetric.timeRemaining.label(for: .zero) == "0m")
  }

  @Test func rawValuesMatchStoredTokens() {
    #expect(
      DayProgressMetric.allCases.map(\.rawValue) == [
        "pct_done", "pct_remaining", "min_elapsed", "min_remaining", "hr_elapsed", "hr_remaining",
        "hr_min_elapsed", "hr_min_remaining",
      ])
  }
}
