import Foundation
import Testing

@testable import SuperZenCore

@Suite struct TypingDeferralTests {
  @Test func typingDefersBreakAtMostTheCap() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1200, activity: .typing)
    #expect(harness.state.isDeferringForTyping)
    harness.run(for: 119, activity: .typing)
    #expect(harness.phase.isNudge)
    harness.run(for: 1, activity: .typing)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func countdownKeepsRunningWhileTyping() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600, activity: .typing)
    #expect(harness.remaining == 600)
  }

  @Test func breakStartsAsSoonAsTypingStops() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1230, activity: .typing)
    #expect(harness.phase.isNudge)
    harness.run(for: 1, activity: ActivitySample(secondsSinceInput: 0, secondsSinceKeyboard: 6))
    #expect(harness.phase.breakKind == .short)
  }

  @Test func nudgeIsShownOnceWhenDeferralStarts() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1300, activity: .typing)
    #expect(harness.visualEffects.filter { $0 == .showNudge }.count == 1)
  }

  @Test func typingIsIgnoredWhenDeferralIsOff() {
    var settings = quietSettings()
    settings.timer.deferWhileTyping = false
    var harness = Harness(settings: settings)
    harness.run(for: 1200, activity: .typing)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.state.isTyping == false)
  }
}

@Suite struct NaturalBreakTests {
  @Test func idleLongerThanThresholdBecomesNaturalBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600)
    harness.runIdle(for: 119)
    #expect(harness.phase.isFocus)
    harness.runIdle(for: 1, alreadyIdle: 119)
    #expect(harness.phase.isNaturalBreak)
    #expect(harness.remaining == 1200)
    #expect(harness.telemetry.last == .focusEnded)
  }

  @Test func returningAfterLongIdleStartsFreshFocusInsteadOfBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 600)
    harness.runIdle(for: 600)
    #expect(harness.phase.isNaturalBreak)
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.visualEffects.isEmpty)
    let outcome = BreakOutcome(kind: .long, completed: true, rested: 601, planned: 300)
    #expect(harness.telemetry == [.naturalBreak(outcome), .focusStarted])
  }

  @Test func naturalBreakCountsTowardLongBreakCycle() {
    var harness = Harness(settings: quietSettings())
    harness.runIdle(for: 150)
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.state.cyclesSinceLongBreak == 1)
    let outcome = BreakOutcome(kind: .short, completed: true, rested: 151, planned: 20)
    #expect(harness.telemetry == [.naturalBreak(outcome), .focusStarted])
  }

  @Test func shortIdleRecordsNoNaturalBreak() {
    var harness = Harness(settings: quietSettings())
    harness.runIdle(for: 60)
    harness.run(for: 1)
    #expect(harness.breakOutcomes.isEmpty)
    #expect(!harness.telemetry.contains { if case .naturalBreak = $0 { return true } else { return false } })
  }

  @Test func idleAsLongAsLongBreakResetsCycle() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1220)
    #expect(harness.state.cyclesSinceLongBreak == 1)
    harness.runIdle(for: 400)
    harness.run(for: 1)
    #expect(harness.state.cyclesSinceLongBreak == 0)
  }

  @Test func idleDuringNudgeHidesNudge() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1190)
    #expect(harness.phase.isNudge)
    harness.clearEffects()
    harness.runIdle(for: 5, alreadyIdle: 118)
    #expect(harness.phase.isNaturalBreak)
    #expect(harness.visualEffects == [.hideOverlays])
  }

  @Test func shortIdleDoesNotResetTimer() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 60)
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 839)
  }
}

@Suite struct SuspendResumeTests {
  @Test func shortSleepResumesFocusWhereItLeftOff() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.send(.suspend(.sleep))
    #expect(harness.phase.pauseReason == .system)
    harness.jump(by: 60)
    harness.send(.resume(.sleep))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 900)
  }

  @Test func longSleepCountsAsNaturalBreakAndLogsNoFakeFocus() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.send(.suspend(.sleep))
    harness.jump(by: 3600)
    harness.send(.resume(.sleep))
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1199)
    #expect(!harness.visualEffects.contains(.showBreak(.short)))
    let active = harness.telemetry.reduce(0.0) { sum, event in
      if case .activeTime(let seconds) = event { return sum + seconds }
      return sum
    }
    #expect(active == 301)
    let natural = BreakOutcome(kind: .long, completed: true, rested: 3600, planned: 300)
    #expect(harness.telemetry.contains(.naturalBreak(natural)))
  }

  @Test func ticksAreIgnoredWhileSuspended() {
    var harness = Harness(settings: quietSettings())
    harness.send(.suspend(.screenLock))
    harness.clearEffects()
    harness.run(for: 30)
    #expect(harness.effects.isEmpty)
    #expect(harness.phase.pauseReason == .system)
  }

  @Test func lockAndSleepBothMustEndBeforeResuming() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 100)
    harness.send(.suspend(.screenLock))
    harness.send(.suspend(.sleep))
    harness.jump(by: 30)
    harness.send(.resume(.sleep))
    #expect(harness.phase.pauseReason == .system)
    harness.send(.resume(.screenLock))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1100)
  }

  @Test func missedWakeNotificationIsRecoveredFromTickGap() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.jump(by: 3600)
    harness.tick()
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(!harness.visualEffects.contains(.showBreak(.short)))
  }

  @Test func sleepThroughBreakCompletesIt() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.suspend(.sleep))
    harness.jump(by: 60)
    harness.send(.resume(.sleep))
    #expect(harness.phase.isFocus)
    #expect(harness.breakOutcomes.last?.completed == true)
    #expect(harness.breakOutcomes.last?.rested == 65)
  }

  @Test func briefSleepDuringBreakRestoresBreakOverlay() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.send(.suspend(.screenLock))
    harness.jump(by: 5)
    harness.clearEffects()
    harness.send(.resume(.screenLock))
    #expect(harness.phase.breakKind == .short)
    #expect(harness.remaining == 15)
    #expect(harness.visualEffects == [.showBreak(.short)])
  }

  @Test func userPauseSurvivesSleep() {
    var harness = Harness(settings: quietSettings())
    harness.send(.togglePause)
    harness.send(.suspend(.sleep))
    harness.jump(by: 3600)
    harness.send(.resume(.sleep))
    #expect(harness.phase.pauseReason == .user)
  }
}
