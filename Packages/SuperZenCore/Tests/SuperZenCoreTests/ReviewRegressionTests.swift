import Foundation
import Testing

@testable import SuperZenCore

@Suite struct NaturalBreakAcrossSuspensionTests {
  @Test func lockDuringNaturalBreakKeepsTheIdleTimeBeforeTheLock() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 300)
    harness.runIdle(for: 180)
    #expect(harness.phase.isNaturalBreak)
    harness.send(.suspend(.screenLock))
    harness.jump(by: 30)
    harness.clearEffects()
    harness.send(.resume(.screenLock))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    #expect(harness.state.continuousActive == 0)
    let outcome = BreakOutcome(kind: .short, completed: true, rested: 210, planned: 20)
    #expect(harness.telemetry == [.naturalBreak(outcome), .focusStarted])
  }

  @Test func sleepDuringNaturalBreakCreditsTheWholeAbsence() {
    var harness = Harness(settings: quietSettings())
    harness.runIdle(for: 200)
    harness.send(.suspend(.sleep))
    harness.jump(by: 200)
    harness.clearEffects()
    harness.send(.resume(.sleep))
    let outcome = BreakOutcome(kind: .long, completed: true, rested: 400, planned: 300)
    #expect(harness.telemetry == [.naturalBreak(outcome), .focusStarted])
    #expect(harness.state.cyclesSinceLongBreak == 0)
  }

  @Test func userPauseDuringNaturalBreakCreditsIdleBeforeThePause() {
    var harness = Harness(settings: quietSettings())
    harness.runIdle(for: 200)
    harness.send(.togglePause)
    harness.jump(by: 1000)
    harness.clearEffects()
    harness.send(.togglePause)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
    let outcome = BreakOutcome(kind: .short, completed: true, rested: 200, planned: 20)
    #expect(harness.telemetry == [.naturalBreak(outcome), .focusStarted])
  }
}

@Suite struct NaturalBreakWellnessTests {
  @Test func returningFromIdleDoesNotFireEveryOverdueReminderAtOnce() {
    var harness = Harness()
    harness.run(for: 60)
    let postureDue = harness.state.wellnessDue[.posture]!
    harness.runIdle(for: 3600)
    harness.clearEffects()
    harness.run(for: 5)
    #expect(harness.phase.isFocus)
    #expect(!harness.visualEffects.contains { if case .showWellness = $0 { return true } else { return false } })
    #expect(harness.state.wellnessDue[.posture] == postureDue.addingTimeInterval(3601))
  }
}

@Suite struct FocusSessionBoundaryTests {
  @Test func scheduledBreakClosesTheFocusSession() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1200)
    #expect(harness.phase.breakKind == .short)
    let focusEvents = harness.telemetry.filter { $0 == .focusStarted || $0 == .focusEnded }
    #expect(focusEvents == [.focusStarted, .focusEnded])
  }

  @Test func manualBreakFromPauseOpensNoFocusSession() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 60)
    harness.send(.togglePause)
    harness.clearEffects()
    harness.send(.startBreak)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.telemetry.isEmpty)
  }

  @Test func pausingAndResumingABreakLeavesSessionsAlone() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 5)
    harness.clearEffects()
    harness.send(.togglePause)
    harness.jump(by: 30)
    harness.send(.togglePause)
    harness.send(.suspend(.screenLock))
    harness.jump(by: 2)
    harness.send(.resume(.screenLock))
    #expect(harness.phase.breakKind == .short)
    #expect(harness.telemetry.isEmpty)
  }

  @Test func recordedSessionsNeverSpanABreak() {
    var harness = Harness(settings: quietSettings())
    var recorder = TelemetryRecorder()
    var openDuringBreak = false
    for _ in 0..<1300 {
      harness.clearEffects()
      harness.run(for: 1)
      for event in harness.telemetry { _ = recorder.record(event, at: harness.now) }
      if harness.phase.breakKind != nil, recorder.sessionID != nil { openDuringBreak = true }
    }
    #expect(!openDuringBreak)
  }
}

@Suite struct WellnessCadenceTests {
  @Test func postureAndBlinkDefaultsAreStaggered() {
    let wellness = WellnessSettings()
    #expect(wellness.blink.interval == 600)
    #expect(wellness.posture.interval == 1800)
  }

  @Test func remindersMissedDuringABreakWaitForMidFocus() {
    var harness = Harness()
    harness.run(for: 1220)
    #expect(harness.phase.isFocus)
    harness.clearEffects()
    harness.run(for: 30)
    #expect(!harness.visualEffects.contains { if case .showWellness = $0 { return true } else { return false } })
    let blinkDue = harness.state.wellnessDue[.blink]!
    #expect(blinkDue == utcDate(2026, 11, 2, 12, 30, 20))
  }

  @Test func remindersNeverFireRightAfterAnyBreakAcrossAnHour() {
    var harness = Harness()
    var lastBreakEnd: Date?
    var tooSoon = false
    for _ in 0..<3600 {
      let wasOnBreak = harness.phase.breakKind != nil
      harness.clearEffects()
      harness.run(for: 1)
      if wasOnBreak, harness.phase.breakKind == nil { lastBreakEnd = harness.now }
      let fired = harness.visualEffects.contains { if case .showWellness = $0 { return true } else { return false } }
      if fired, let end = lastBreakEnd, harness.now.timeIntervalSince(end) < 60 { tooSoon = true }
    }
    #expect(!tooSoon)
  }

  @Test func usersOnTheOldSharedDefaultMoveToTheStaggeredOne() {
    let updates = WellnessCadenceMigration.updates(storedVersion: 0, posture: 1200, blink: 1200)
    #expect(updates == [.postureFrequency: 1800, .blinkFrequency: 600])
  }

  @Test func customOrAlreadyMigratedCadencesAreKept() {
    #expect(WellnessCadenceMigration.updates(storedVersion: 0, posture: 1200, blink: 900).isEmpty)
    #expect(WellnessCadenceMigration.updates(storedVersion: 0, posture: nil, blink: nil).isEmpty)
    #expect(WellnessCadenceMigration.updates(storedVersion: 1, posture: 1200, blink: 1200).isEmpty)
  }
}
