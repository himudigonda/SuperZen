import Foundation
import Testing

@testable import SuperZenCore

private func nudging(_ settings: Settings = quietSettings()) -> Harness {
  var harness = Harness(settings: settings)
  harness.run(for: settings.timer.workDuration - settings.timer.nudgeLeadTime)
  return harness
}

private func breaking(_ settings: Settings = quietSettings(), afterSeconds rested: TimeInterval = 15) -> Harness {
  var harness = nudging(settings)
  harness.run(for: settings.timer.nudgeLeadTime)
  harness.run(for: rested)
  return harness
}

@Suite struct PostponeFromNudgeTests {
  @Test func returnsToFocusForTheSnoozeDurationWithoutABreakOutcome() {
    var harness = nudging()
    #expect(harness.phase.isNudge)
    harness.clearEffects()
    harness.send(.postpone(nil))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 300)
    #expect(harness.visualEffects == [.hideOverlays])
    #expect(harness.telemetry.isEmpty)
    #expect(harness.state.postponesUsed == 1)
  }

  @Test func anExplicitDurationIsClampedToTheMaximum() {
    var harness = nudging()
    harness.send(.postpone(1e12))
    #expect(harness.remaining == Settings.maximumDuration)
  }

  @Test func invalidDurationsAreIgnored() {
    for invalid in [0, -5, .nan, .infinity] as [TimeInterval] {
      var harness = nudging()
      harness.send(.postpone(invalid))
      #expect(harness.phase.isNudge, "\(invalid)")
      #expect(harness.state.postponesUsed == 0)
    }
  }

  @Test func theCapAppliesPerBlockAndTheBlockKeepsTheCountWhenItEnds() {
    var harness = nudging()
    harness.send(.postpone(60))
    harness.run(for: 50)
    #expect(harness.phase.isNudge)
    harness.send(.postpone(60))
    #expect(harness.state.postponesUsed == 2)
    harness.run(for: 50)
    #expect(harness.phase.isNudge)
    harness.send(.postpone(60))
    #expect(harness.phase.isNudge)
    #expect(harness.state.postponesUsed == 2)
  }

  @Test func theCountSurvivesThePostponedBlockReachingItsBreak() {
    var harness = nudging()
    harness.send(.postpone(60))
    harness.run(for: 60)
    #expect(harness.phase.breakKind != nil)
    #expect(harness.state.postponesUsed == 1)
  }

  @Test func aZeroCapRefusesEverything() {
    var settings = quietSettings()
    settings.timer.maxPostpones = 0
    var harness = nudging(settings)
    harness.send(.postpone(60))
    #expect(harness.phase.isNudge)
  }

  @Test func hardcoreRefuses() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = nudging(settings)
    harness.send(.postpone(60))
    #expect(harness.phase.isNudge)
    #expect(harness.state.postponesUsed == 0)
  }

  @Test func ignoredOutsideNudgeAndBreak() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 10)
    harness.send(.postpone(60))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1190)
    harness.send(.togglePause)
    harness.send(.postpone(60))
    #expect(harness.phase.pauseReason == .user)
    #expect(harness.state.postponesUsed == 0)
  }

  @Test func skippingTheNudgeResetsTheCount() {
    var harness = nudging()
    harness.send(.postpone(60))
    harness.run(for: 55)
    harness.send(.skipBreak)
    #expect(harness.state.postponesUsed == 0)
  }

  @Test func aNaturalBreakResetsTheCount() {
    var harness = nudging()
    harness.send(.postpone(600))
    harness.runIdle(for: 130)
    #expect(harness.phase.isNaturalBreak)
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.state.postponesUsed == 0)
  }

  @Test func pausingAndResumingDoesNotResetTheCount() {
    var harness = nudging()
    harness.send(.postpone(600))
    harness.send(.togglePause)
    harness.run(for: 30)
    harness.send(.togglePause)
    #expect(harness.state.postponesUsed == 1)
  }

  @Test func continuousActiveTimeIsNotReset() {
    var harness = nudging()
    let before = harness.state.continuousActive
    #expect(before > 0)
    harness.send(.postpone(60))
    #expect(harness.state.continuousActive == before)
  }
}

@Suite struct PostponeFromBreakTests {
  @Test func returnsToFocusAndReportsAPostponedOutcome() {
    var harness = breaking()
    #expect(harness.phase.breakKind == .short)
    harness.clearEffects()
    harness.send(.postpone(nil))
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 300)
    #expect(harness.visualEffects == [.hideOverlays])
    #expect(
      harness.telemetry == [
        .breakEnded(BreakOutcome(kind: .short, completed: false, rested: 15, planned: 20, postponed: true)),
        .focusStarted,
      ])
    #expect(harness.state.postponesUsed == 1)
  }

  @Test func theBalancedSkipLockStillApplies() {
    var harness = breaking(afterSeconds: 5)
    harness.send(.postpone(60))
    #expect(harness.phase.breakKind == .short)
    #expect(harness.state.postponesUsed == 0)
    harness.run(for: 5)
    harness.send(.postpone(60))
    #expect(harness.phase.isFocus)
  }

  @Test func hardcoreRefuses() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    var harness = breaking(settings, afterSeconds: 19)
    harness.send(.postpone(60))
    #expect(harness.phase.breakKind == .short)
  }

  @Test func casualCanPostponeImmediately() {
    var settings = quietSettings()
    settings.skipPolicy.difficulty = .casual
    var harness = breaking(settings, afterSeconds: 0)
    harness.send(.postpone(60))
    #expect(harness.phase.isFocus)
  }

  @Test func theSecondPostponeWorksAndTheThirdIsRefused() {
    var harness = breaking()
    harness.send(.postpone(30))
    harness.run(for: 30)
    harness.run(for: 15)
    #expect(harness.phase.breakKind == .short)
    harness.send(.postpone(30))
    #expect(harness.state.postponesUsed == 2)
    harness.run(for: 30)
    harness.run(for: 15)
    harness.send(.postpone(30))
    #expect(harness.phase.breakKind == .short)
    #expect(harness.state.postponesUsed == 2)
  }

  @Test func restoresTheCycleCountSoTheNextBreakKindIsUnchanged() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 2
    var harness = breaking(settings)
    #expect(harness.state.cyclesSinceLongBreak == 1)
    #expect(harness.state.nextBreakKind == .long)
    harness.send(.postpone(30))
    #expect(harness.state.cyclesSinceLongBreak == 0)
    #expect(harness.state.nextBreakKind == .short)
    harness.run(for: 30)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func postponingALongBreakRestoresTheCounterThatTheBreakReset() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 2
    settings.timer.longBreakDuration = 60
    var harness = breaking(settings)
    harness.run(for: 5)
    #expect(harness.phase.isFocus)
    #expect(harness.state.cyclesSinceLongBreak == 1)
    harness.run(for: 1200)
    #expect(harness.phase.breakKind == .long)
    #expect(harness.state.cyclesSinceLongBreak == 0)
    harness.run(for: 25)
    harness.send(.postpone(30))
    #expect(harness.phase.isFocus)
    #expect(harness.state.cyclesSinceLongBreak == 1)
    #expect(harness.state.nextBreakKind == .long)
    harness.run(for: 30)
    #expect(harness.phase.breakKind == .long)
  }

  @Test func theRestoredCountSurvivesAMidBreakSettingsChange() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 2
    var harness = breaking(settings)
    var edited = settings
    edited.timer.shortBreakDuration = 40
    harness.send(.settingsChanged(edited))
    harness.run(for: 25)
    harness.send(.postpone(30))
    #expect(harness.phase.isFocus)
    #expect(harness.state.cyclesSinceLongBreak == 0)
  }

  @Test func continuousActiveTimeIsNotReset() {
    var harness = breaking()
    let before = harness.state.continuousActive
    #expect(before > 0)
    harness.send(.postpone(30))
    #expect(harness.state.continuousActive == before)
  }

  @Test func completingTheBreakAfterPostponesResetsTheCount() {
    var harness = breaking()
    harness.send(.postpone(30))
    harness.run(for: 30)
    harness.run(for: 25)
    #expect(harness.phase.isFocus)
    #expect(harness.state.postponesUsed == 0)
  }

  @Test func skippingTheBreakAfterAPostponeResetsTheCount() {
    var harness = breaking()
    harness.send(.postpone(30))
    harness.run(for: 30)
    harness.run(for: 15)
    harness.send(.skipBreak)
    #expect(harness.phase.isFocus)
    #expect(harness.state.postponesUsed == 0)
  }
}

@Suite struct PostponeSurfaceTests {
  @Test func menuActionsOfferPostponeInNudgeAndAfterTheSkipLock() {
    var harness = nudging()
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).actions.canPostpone)
    harness.run(for: 10)
    harness.run(for: 5)
    #expect(!MenuBarSnapshot(state: harness.state, at: harness.now).actions.canPostpone)
    harness.run(for: 5)
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).actions.canPostpone)
  }

  @Test func menuActionsHidePostponeWhenTheCapIsReachedAndInFocusAndHardcore() {
    var harness = nudging()
    harness.send(.postpone(60))
    #expect(!MenuBarSnapshot(state: harness.state, at: harness.now).actions.canPostpone)

    var capped = nudging()
    capped.send(.postpone(60))
    capped.run(for: 50)
    capped.send(.postpone(60))
    capped.run(for: 50)
    #expect(capped.phase.isNudge)
    #expect(!MenuBarSnapshot(state: capped.state, at: capped.now).actions.canPostpone)

    var settings = quietSettings()
    settings.skipPolicy.difficulty = .hardcore
    let hardcore = nudging(settings)
    #expect(!MenuBarSnapshot(state: hardcore.state, at: hardcore.now).actions.canPostpone)
    #expect(!MenuBarActions.none.canPostpone)
  }
}

@Suite struct PostponeTelemetryTests {
  private let outcome = BreakOutcome(kind: .short, completed: false, rested: 12, planned: 20, postponed: true)

  @Test func aPostponedOutcomeBecomesAPostponedRecordThatWasNotTaken() {
    var recorder = TelemetryRecorder()
    _ = recorder.record(.focusStarted, at: mondayNoon)
    let records = recorder.record(.breakEnded(outcome), at: mondayNoon.addingTimeInterval(12))
    let breaks = records.compactMap { record -> BreakRecord? in
      if case .breakTaken(let value) = record { return value }
      return nil
    }
    #expect(breaks.map(\.result) == [.postponed])
    #expect(breaks.first?.result.wasTaken == false)
    #expect(BreakResult.allCases.contains(.postponed))
  }

  @Test func insightsCountNeitherTakenNorSkippedForAPostponedBreak() {
    let end = mondayNoon
    func record(_ result: BreakResult) -> BreakRecord {
      BreakRecord(kind: .short, result: result, start: end.addingTimeInterval(-20), end: end, planned: 20)
    }
    let data = TelemetrySnapshot(breaks: [record(.completed), record(.skipped), record(.postponed), record(.postponed)])
    let configuration = InsightsConfiguration(
      goals: InsightsGoals(focusMinutes: 60, breaks: 4, wellness: 4), workWindow: nil, interruptionThreshold: 30)
    let insights = InsightsCalculator(calendar: .utc).compute(
      .today, at: mondayNoon.addingTimeInterval(60), data: data, configuration: configuration)
    #expect(insights.breaksTaken == 1)
    #expect(insights.breaksSkipped == 1)
    #expect(insights.breakRate == 0.5)
    #expect(insights.skipRate == 0.5)
  }

  @Test func aPostponedBreakContributesNoRestToTheTimeline() {
    let end = utcDate(2026, 11, 2, 10)
    func record(_ result: BreakResult) -> BreakRecord {
      BreakRecord(kind: .short, result: result, start: end.addingTimeInterval(-20), end: end, planned: 20)
    }
    let timeline = InsightsCalculator(calendar: .utc).timeline(
      on: mondayNoon, at: mondayNoon, data: TelemetrySnapshot(breaks: [record(.postponed)]))
    #expect(timeline.total(.rest) == 0)
  }
}
