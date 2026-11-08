import Foundation
import Testing

@testable import SuperZenCore

@Suite struct ReleaseAuditTests {
  @Test func extendingABreakDoesNotRelockSkip() {
    var harness = Harness(settings: quietSettings())
    harness.send(.startBreak)
    harness.run(for: 12)
    #expect(harness.state.canSkip(at: harness.now))
    harness.send(.extendBreak(60))
    #expect(harness.state.canSkip(at: harness.now))
  }

  @Test func hardcoreCannotSnooze() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = Harness(settings: settings)
    harness.run(for: 1195)
    harness.send(.snooze(nil))
    #expect(harness.phase.isNudge)
    #expect(MenuBarActions(state: harness.state, at: harness.now).canSnooze == false)
  }

  @Test func snoozeSpendsTheSameBudgetAsPostpone() {
    var harness = Harness(settings: quietSettings())
    for _ in 0..<2 {
      harness.run(for: harness.remaining - 5)
      harness.send(.snooze(nil))
      #expect(harness.phase.isFocus)
    }
    harness.run(for: harness.remaining - 5)
    #expect(harness.state.postponesUsed == 2)
    harness.send(.snooze(nil))
    #expect(harness.phase.isNudge)
  }

  @Test func skippingALongBreakKeepsItDue() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 2
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    harness.run(for: 20)
    #expect(harness.state.nextBreakKind == .long)
    harness.send(.startBreak)
    #expect(harness.phase.breakKind == .long)
    harness.run(for: 20)
    harness.send(.skipBreak)
    #expect(harness.state.nextBreakKind == .long)
  }

  @Test func skippingALongNudgeKeepsItDue() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 1
    var harness = Harness(settings: settings)
    harness.run(for: 1195)
    harness.send(.skipBreak)
    #expect(harness.state.nextBreakKind == .long)
  }

  @Test func soundsStayQuietDuringACallButTheBreakStillShows() {
    var harness = Harness(settings: quietSettings())
    harness.send(.context(ContextSample(isMicrophoneInUse: true)))
    harness.clearEffects()
    harness.send(.startBreak)
    #expect(harness.visualEffects == [.showBreak(.short)])
  }

  @Test func plannedBreakWaitsForACallWithinGrace() {
    var settings = quietSettings()
    settings.plannedBreaks = [PlannedBreak(id: "lunch", minuteOfDay: 12 * 60 + 1, weekdays: [2], duration: 600)]
    var harness = Harness(settings: settings)
    harness.send(.context(ContextSample(isMicrophoneInUse: true)))
    harness.run(for: 90)
    #expect(harness.phase.isFocus)
    #expect(harness.state.plannedBreaksFired["lunch"] == nil)
    harness.send(.context(.unknown))
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func deadlineMissedDuringWellnessStillGetsAHeadsUp() {
    var settings = quietSettings()
    settings.wellness.blink = Reminder(enabled: true, interval: 1189)
    var harness = Harness(settings: settings)
    harness.run(for: 1189)
    #expect(harness.phase.wellnessKind == .blink)
    harness.jump(by: 12)
    harness.clearEffects()
    harness.tick()
    #expect(harness.phase.isNudge)
    #expect(harness.visualEffects.contains(.showNudge))
  }

  @Test func awayHasItsOwnGlyph() {
    var harness = Harness(settings: quietSettings())
    harness.runIdle(for: 120)
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).glyph == .away)
  }

  @Test func pauseIsNotOfferedWhereTheEngineIgnoresIt() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    #expect(MenuBarActions(state: harness.state, at: harness.now).canPause == false)
    harness.run(for: 20)
    harness.send(.suspend(.screenLock))
    #expect(MenuBarActions(state: harness.state, at: harness.now).canPause == false)
  }
}
