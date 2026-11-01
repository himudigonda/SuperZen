import Foundation
import Testing

@testable import SuperZenCore

@Suite struct FocusCycleTests {
  @Test func defaultsAreTwentyTwentyTwentyWithLongBreakEveryFourthCycle() {
    let timer = Settings().timer
    #expect(timer.workDuration == 1200)
    #expect(timer.shortBreakDuration == 20)
    #expect(timer.longBreakDuration == 300)
    #expect(timer.longBreakEvery == 4)
    #expect(timer.typingDeferralCap == 120)
  }

  @Test func startOpensFocusSessionWithFullWorkDuration() {
    let harness = Harness(settings: quietSettings())
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.telemetry == [.focusStarted])
  }

  @Test func focusMovesToNudgeThenBreakThenBackToFocus() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1189)
    #expect(harness.phase.isFocus)

    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.isNudge)
    #expect(harness.visualEffects == [.showNudge])

    harness.clearEffects()
    harness.run(for: 10)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.visualEffects == [.hideOverlays, .showBreak(.short), .play(.breakStart)])

    harness.clearEffects()
    harness.run(for: 20)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.breakOutcomes == [BreakOutcome(kind: .short, completed: true, rested: 20, planned: 20)])
    #expect(harness.visualEffects == [.hideOverlays, .play(.breakEnd)])
  }

  @Test func everyFourthBreakIsLong() {
    var harness = Harness(settings: quietSettings())
    var kinds: [BreakKind] = []
    for _ in 0..<5 {
      harness.run(for: 1200)
      kinds.append(harness.phase.breakKind!)
      harness.run(for: harness.remaining)
    }
    #expect(kinds == [.short, .short, .short, .long, .short])
  }

  @Test func longBreaksCanBeTurnedOff() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 0
    var harness = Harness(settings: settings)
    for _ in 0..<4 {
      harness.run(for: 1200)
      #expect(harness.phase.breakKind == .short)
      harness.run(for: 20)
    }
  }

  @Test func activeAndIdleTimeAreAccountedPerTick() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 30)
    harness.runIdle(for: 30)
    let active = harness.telemetry.reduce(0.0) { sum, event in
      if case .activeTime(let seconds) = event { return sum + seconds }
      return sum
    }
    let idle = harness.telemetry.reduce(0.0) { sum, event in
      if case .idleTime(let seconds) = event { return sum + seconds }
      return sum
    }
    #expect(active == 49)
    #expect(idle == 11)
    #expect(harness.state.continuousActive == 49)
  }

  @Test func manualBreakResumesRemainingFocusWhenResetIsOff() {
    var settings = quietSettings()
    settings.timer.resetFocusAfterBreak = false
    var harness = Harness(settings: settings)
    harness.run(for: 300)
    harness.send(.startBreak)
    harness.run(for: 20)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 900)
  }

  @Test func manualBreakRestartsFullFocusByDefault() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.send(.startBreak)
    harness.run(for: 20)
    #expect(harness.remaining == 1200)
  }

  @Test func clockJumpingBackwardsDoesNotCountNegativeTime() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 10)
    harness.jump(by: -5)
    harness.clearEffects()
    harness.tick()
    #expect(harness.telemetry.isEmpty)
    #expect(harness.phase.isFocus)
  }
}
