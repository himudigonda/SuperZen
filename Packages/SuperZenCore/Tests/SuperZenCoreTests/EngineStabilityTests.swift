import Foundation
import Testing

@testable import SuperZenCore

private func naturalBreaks(_ harness: Harness) -> [BreakOutcome] {
  harness.telemetry.compactMap {
    if case .naturalBreak(let outcome) = $0 { return outcome }
    return nil
  }
}

@Suite struct EngineStabilityTests {
  @Test func awayThroughLongBreakIsNotCountedTwice() {
    var harness = Harness(settings: quietSettings())
    harness.state.cyclesSinceLongBreak = 3
    harness.run(for: 1200)
    #expect(harness.phase.breakKind == .long)
    harness.clearEffects()
    harness.runIdle(for: 400)
    harness.tick(.present)
    #expect(harness.breakOutcomes.count == 1)
    #expect(naturalBreaks(harness).isEmpty, "natural breaks: \(naturalBreaks(harness))")
  }

  @Test func lockPartwayThroughAbsenceCountsAsNaturalBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 100)
    harness.send(.suspend(.screenLock))
    harness.jump(by: 30)
    harness.clearEffects()
    harness.send(.resume(.screenLock))
    #expect(naturalBreaks(harness).count == 1, "telemetry: \(harness.telemetry)")
  }

  @Test func tickGapDuringNaturalBreakCreditsOnce() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 200)
    #expect(harness.phase.isNaturalBreak)
    harness.clearEffects()
    harness.jump(by: 100)
    harness.tick(.away(for: 300))
    harness.jump(by: 1)
    harness.tick(.present)
    #expect(naturalBreaks(harness).count == 1, "natural breaks: \(naturalBreaks(harness))")
  }

  @Test func hardcoreBreakCannotBePaused() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = Harness(settings: settings)
    harness.run(for: 1200)
    #expect(harness.phase.breakKind == .short)
    harness.send(.togglePause)
    #expect(harness.phase.breakKind == .short, "phase: \(harness.phase)")
  }

  @Test func shortIdleThenShortLockIsNotANaturalBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 20)
    harness.send(.suspend(.screenLock))
    harness.jump(by: 20)
    harness.clearEffects()
    harness.send(.resume(.screenLock))
    #expect(naturalBreaks(harness).isEmpty)
    #expect(harness.phase.isFocus)
  }

  @Test func idleBeforeFocusStartedIsNotCredited() {
    var harness = Harness(settings: quietSettings())
    harness.send(.togglePause)
    harness.jump(by: 600)
    harness.send(.togglePause)
    harness.clearEffects()
    harness.tick(.away(for: 650))
    #expect(harness.phase.isFocus)
    #expect(naturalBreaks(harness).isEmpty)
  }

  @Test func tickGapWhileStillAwayKeepsTheNaturalBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 200)
    harness.clearEffects()
    harness.jump(by: 100)
    harness.tick(.away(for: 300))
    #expect(harness.phase.isNaturalBreak)
    #expect(naturalBreaks(harness).isEmpty)
  }

  @Test func casualBreakCanStillBePaused() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1200)
    harness.send(.togglePause)
    #expect(harness.phase.pauseReason == .user)
  }

  @Test func idleBeforeAnUnannouncedSleepCountsTowardANaturalBreak() {
    var harness = Harness(settings: quietSettings())
    let threshold = harness.state.settings.timer.naturalBreakThreshold
    harness.run(for: 300)
    harness.runIdle(for: threshold - 10)
    harness.clearEffects()
    harness.jump(by: SessionEngine.maxTickGap + 10)
    harness.tick(.present)
    #expect(naturalBreaks(harness).count == 1, "telemetry: \(harness.telemetry)")
  }
}
