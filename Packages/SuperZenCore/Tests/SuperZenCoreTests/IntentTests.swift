import Foundation
import Testing

@testable import SuperZenCore

@Suite struct SkipPolicyTests {
  private func harness(_ difficulty: BreakDifficulty) -> Harness {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = difficulty
    return Harness(settings: settings)
  }

  @Test func balancedLocksSkipForHalfTheBreak() {
    var harness = harness(.balanced)
    harness.send(.startBreak)
    #expect(harness.state.skipLockRemaining(at: harness.now) == 10)
    harness.send(.skipBreak)
    #expect(harness.phase.breakKind == .short)
    harness.run(for: 10)
    harness.send(.skipBreak)
    #expect(harness.phase.isFocus)
    #expect(harness.breakOutcomes == [BreakOutcome(kind: .short, completed: false, rested: 10, planned: 20)])
  }

  @Test func balancedLockIsCappedAtTwentySeconds() {
    var settings = quietSettings()
    settings.timer.shortBreakDuration = 600
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    #expect(harness.state.skipLockRemaining(at: harness.now) == 20)
  }

  @Test func hardcoreNeverSkips() {
    var harness = harness(.hardcore)
    harness.send(.startBreak)
    harness.run(for: 19)
    harness.send(.skipBreak)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.state.canSkip(at: harness.now) == false)
  }

  @Test func casualSkipsImmediately() {
    var harness = harness(.casual)
    harness.send(.startBreak)
    harness.send(.skipBreak)
    #expect(harness.phase.isFocus)
  }

  @Test func skippingFromNudgeIsLoggedAsSkippedBreak() {
    var harness = harness(.balanced)
    harness.run(for: 1190)
    harness.send(.skipBreak)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.breakOutcomes == [BreakOutcome(kind: .short, completed: false, rested: 0, planned: 20)])
    #expect(harness.state.cyclesSinceLongBreak == 1)
  }

  @Test func hardcoreCannotSkipFromNudge() {
    var harness = harness(.hardcore)
    harness.run(for: 1190)
    harness.send(.skipBreak)
    #expect(harness.phase.isNudge)
  }

  @Test func pausedTimeDoesNotCountAsRest() {
    var harness = harness(.casual)
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.togglePause)
    harness.jump(by: 100)
    harness.send(.togglePause)
    harness.run(for: 5)
    harness.send(.skipBreak)
    #expect(harness.breakOutcomes.last == BreakOutcome(kind: .short, completed: false, rested: 10, planned: 20))
  }

  @Test func extendedBreakSkippedAfterOriginalLengthIsNotCompleted() {
    var harness = harness(.casual)
    harness.send(.startBreak)
    harness.send(.extendBreak(60))
    #expect(harness.remaining == 80)
    harness.run(for: 25)
    harness.send(.skipBreak)
    #expect(harness.breakOutcomes.last == BreakOutcome(kind: .short, completed: false, rested: 25, planned: 80))
  }
}

@Suite struct IntentTests {
  @Test func snoozePushesDeadlineAndHidesNudge() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1190)
    harness.clearEffects()
    harness.send(.snooze(300))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 310)
    #expect(harness.visualEffects == [.hideOverlays])
  }

  @Test func snoozeUsesSettingWhenNoDurationGiven() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1190)
    harness.send(.snooze(nil))
    #expect(harness.remaining == 310)
  }

  @Test func snoozeOutsideNudgeDoesNothing() {
    var harness = Harness(settings: quietSettings())
    harness.send(.snooze(300))
    #expect(harness.remaining == 1200)
  }

  @Test func pauseAndResumeKeepsFocusRemaining() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.send(.togglePause)
    #expect(harness.phase.pauseReason == .user)
    #expect(harness.remaining == 900)
    harness.jump(by: 1000)
    harness.send(.togglePause)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 900)
    #expect(Array(harness.telemetry.suffix(2)) == [.focusEnded, .focusStarted])
  }

  @Test func pauseDuringBreakResumesBreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.togglePause)
    harness.jump(by: 100)
    harness.clearEffects()
    harness.send(.togglePause)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.remaining == 15)
    #expect(harness.visualEffects == [.showBreak(.short)])
  }

  @Test func startBreakWhilePausedMidBreakResumesThatBreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.togglePause)
    harness.send(.startBreak)
    #expect(harness.remaining == 15)
  }

  @Test func startBreakIsIgnoredDuringBreak() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.startBreak)
    #expect(harness.remaining == 15)
  }

  @Test func extendOutsideBreakDoesNothing() {
    var harness = Harness(settings: quietSettings())
    harness.send(.extendBreak(60))
    #expect(harness.remaining == 1200)
  }

  @Test func pausedTimeShiftsWellnessDueTimes() {
    var harness = Harness()
    let due = harness.state.wellnessDue[.posture]!
    harness.send(.togglePause)
    harness.jump(by: 500)
    harness.send(.togglePause)
    #expect(harness.state.wellnessDue[.posture] == due.addingTimeInterval(500))
  }
}
