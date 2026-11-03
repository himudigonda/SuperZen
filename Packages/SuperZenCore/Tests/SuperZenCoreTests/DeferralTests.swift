import Foundation
import Testing

@testable import SuperZenCore

private let keynote = ContextSample(frontmostBundleID: "com.apple.iWork.Keynote")
private let zoom = ContextSample(frontmostBundleID: "us.zoom.xos")
private let editor = ContextSample(frontmostBundleID: "com.apple.dt.Xcode")

private func deferring(cap: TimeInterval = 600, recheck: TimeInterval = 15) -> Settings {
  var settings = quietSettings()
  settings.deferral.apps = ["com.apple.iWork.Keynote", "us.zoom.xos"]
  settings.deferral.cap = cap
  settings.deferral.recheck = recheck
  return settings
}

extension Harness {
  fileprivate var focusBlock: FocusBlock? {
    if case .focus(let block) = phase { return block }
    return nil
  }

  fileprivate var showsAnyOverlayEffect: Bool {
    visualEffects.contains {
      switch $0 {
      case .showNudge, .showBreak, .showWellness, .play: return true
      default: return false
      }
    }
  }
}

@Suite struct DeferralTests {
  @Test func listedAppAtTheDeadlineKeepsFocusSilently() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.clearEffects()
    harness.run(for: 1200)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects.isEmpty)
    let block = harness.focusBlock
    #expect(block?.contextDeferralStartedAt == harness.now)
    #expect(block?.deadline == harness.now.addingTimeInterval(15))
    #expect(harness.state.isDeferringForContext)
    #expect(MenuBarSnapshot(state: harness.state, at: harness.now).deferredByApp)
  }

  @Test func noNudgeAtTheLeadTimeWhileListedAppIsFrontmost() {
    var harness = Harness(settings: deferring())
    harness.send(.context(zoom))
    harness.clearEffects()
    harness.run(for: 1195)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects.isEmpty)
    #expect(!harness.state.isDeferringForContext)
  }

  @Test func unlistedAppBehavesLikeNoContext() {
    var harness = Harness(settings: deferring())
    harness.send(.context(editor))
    harness.run(for: 1190)
    #expect(harness.phase.isNudge)
    harness.run(for: 10)
    #expect(harness.phase.breakKind == .short)
  }

  @Test(arguments: [(600.0, 15.0), (100.0, 15.0), (100.0, 7.0), (45.0, 60.0), (3.0, 1.0)])
  func capIsExactAcrossALongRunOfTicks(cap: TimeInterval, recheck: TimeInterval) {
    var harness = Harness(settings: deferring(cap: cap, recheck: recheck))
    harness.send(.context(keynote))
    harness.run(for: 1200)
    let startedAt = harness.now
    #expect(harness.phase.isFocus)
    var elapsed: TimeInterval = 0
    while elapsed < cap - 1 {
      harness.run(for: 1)
      elapsed += 1
      #expect(harness.phase.isFocus, "still focus at \(elapsed)")
      if let block = harness.focusBlock, let began = block.contextDeferralStartedAt {
        #expect(began == startedAt)
        #expect(block.deadline.isAtOrBefore(began.addingTimeInterval(cap + recheck)))
      }
    }
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.now == startedAt.addingTimeInterval(cap))
    #expect(harness.visualEffects == [.showBreak(.short), .play(.breakStart)])
  }

  @Test func breakStartsEvenWhenTheAppIsStillFrontmostAtTheCap() {
    var harness = Harness(settings: deferring(cap: 60))
    harness.send(.context(keynote))
    harness.run(for: 1260)
    #expect(harness.phase.breakKind == .short)
    harness.run(for: 20)
    #expect(harness.phase.isFocus)
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
  }

  @Test func breakStartsOnTheTickTheAppLeaves() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1207)
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 8)
    harness.send(.context(editor))
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .short)
    #expect(harness.visualEffects == [.showBreak(.short), .play(.breakStart)])
  }

  @Test func switchingBetweenListedAppsKeepsDeferring() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1210)
    harness.send(.context(zoom))
    harness.run(for: 30)
    #expect(harness.phase.isFocus)
    #expect(harness.state.isDeferringForContext)
  }

  @Test func nudgeIsHiddenWhenTheListedAppComesToTheFront() {
    var harness = Harness(settings: deferring())
    harness.run(for: 1192)
    #expect(harness.phase.isNudge)
    let deadline = harness.state.remaining(at: harness.now)
    harness.send(.context(keynote))
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects == [.hideOverlays])
    #expect(harness.remaining == deadline - 1)
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
    harness.clearEffects()
    harness.run(for: 7)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects.isEmpty)
    #expect(harness.state.isDeferringForContext)
  }

  @Test func nudgeReturnsWhenTheAppLeavesAgainAfterBeingHidden() {
    var harness = Harness(settings: deferring())
    harness.run(for: 1192)
    harness.send(.context(keynote))
    harness.run(for: 1)
    harness.send(.context(editor))
    harness.run(for: 1)
    #expect(harness.phase.isNudge)
  }

  @Test func wellnessWaitsWhileTheListedAppIsFrontmost() {
    var settings = deferring()
    settings.wellness.blink = Reminder(enabled: true, interval: 60)
    var harness = Harness(settings: settings)
    harness.send(.context(keynote))
    harness.clearEffects()
    harness.run(for: 600)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects.isEmpty)
    harness.send(.context(editor))
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.wellnessKind == .blink)
    let pulses = harness.visualEffects.filter {
      if case .showWellness = $0 { return true }
      return false
    }
    #expect(pulses.count == 1)
  }

  @Test func wellnessDoesNotBurstAfterTheAppLeaves() {
    var settings = deferring()
    settings.wellness.blink = Reminder(enabled: true, interval: 60)
    var harness = Harness(settings: settings)
    harness.send(.context(keynote))
    harness.run(for: 900)
    harness.send(.context(editor))
    harness.clearEffects()
    harness.run(for: 30)
    let pulses = harness.visualEffects.filter {
      if case .showWellness = $0 { return true }
      return false
    }
    #expect(pulses.count == 1)
  }

  @Test func disabledListMatchesTodaysTransitionsExactly() {
    var settings = quietSettings()
    settings.wellness.blink = Reminder(enabled: true, interval: 90)
    var capZero = settings
    capZero.deferral.apps = ["com.apple.iWork.Keynote"]
    capZero.deferral.cap = 0
    var emptyList = settings
    emptyList.deferral.cap = 600

    for variant in [capZero, emptyList] {
      var plain = Harness(settings: settings)
      var withContext = Harness(settings: variant)
      withContext.send(.context(keynote))
      for second in 0..<2600 {
        if second % 50 == 0 { withContext.send(.context(second % 100 == 0 ? keynote : editor)) }
        plain.run(for: 1)
        withContext.run(for: 1)
        #expect(plain.phase == withContext.phase, "second \(second)")
      }
      let plainEffects = plain.effects
      #expect(plainEffects == withContext.effects)
      #expect(!withContext.state.isDeferringForContext)
    }
  }

  @Test func typingDeferralTakesOverOnlyAfterTheAppLeaves() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.clearEffects()
    harness.run(for: 1230, activity: .typing)
    #expect(harness.phase.isFocus)
    #expect(harness.visualEffects.isEmpty)
    harness.send(.context(editor))
    harness.run(for: 1, activity: .typing)
    #expect(harness.phase.isNudge)
    #expect(harness.visualEffects == [.showNudge])
  }

  @Test func manualBreakAlwaysWorksWhileDeferring() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1230)
    harness.send(.startBreak)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func userPauseDuringDeferralResumesWithAFreshBlock() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1230)
    harness.send(.togglePause)
    #expect(harness.phase.pauseReason == .user)
    harness.run(for: 100)
    harness.send(.togglePause)
    #expect(harness.phase.isFocus)
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
    #expect(!harness.state.isDeferringForContext)
  }

  @Test func suspendDuringDeferralPausesAndWakesWithoutAStaleDeferral() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1230)
    harness.send(.suspend(.sleep))
    #expect(harness.phase.pauseReason == .system)
    harness.jump(by: 30)
    harness.send(.resume(.sleep))
    #expect(harness.phase.isFocus)
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
  }

  @Test func scheduleSleepStillWinsOverDeferral() {
    var settings = deferring()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 540, endMinute: 12 * 60 + 5)
    var harness = Harness(settings: settings)
    harness.send(.context(keynote))
    harness.run(for: 400)
    #expect(harness.phase.pauseReason == .schedule)
  }

  @Test func naturalBreakDetectionIsUnchangedWhileListed() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.runIdle(for: 120)
    #expect(harness.phase.isNaturalBreak)
  }

  @Test func freshBlocksCarryNoDeferralState() {
    var harness = Harness(settings: deferring())
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
    harness.send(.context(keynote))
    harness.run(for: 1230)
    harness.send(.context(editor))
    harness.run(for: 1)
    harness.run(for: 20)
    #expect(harness.phase.isFocus)
    #expect(harness.focusBlock?.contextDeferralStartedAt == nil)
  }

  @Test func clockStepBackDuringDeferralKeepsTheCapMeasuredInRealTime() {
    var harness = Harness(settings: deferring(cap: 100))
    harness.send(.context(keynote))
    harness.run(for: 1200)
    harness.run(for: 40)
    harness.jump(by: -500)
    harness.tick()
    #expect(harness.phase.isFocus)
    #expect(harness.state.isDeferringForContext)
    harness.run(for: 59)
    #expect(harness.phase.isFocus)
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func clockStepBackBeforeTheDeferralStartCannotExtendTheCap() {
    var harness = Harness(settings: deferring(cap: 100))
    harness.send(.context(keynote))
    harness.run(for: 1200)
    guard var block = harness.focusBlock else { return }
    block.contextDeferralStartedAt = harness.now.addingTimeInterval(500)
    harness.state.phase = .focus(block)
    harness.run(for: 15)
    #expect(harness.focusBlock?.contextDeferralStartedAt == harness.now)
    #expect(harness.focusBlock?.deadline == harness.now.addingTimeInterval(15))
  }

  @Test func staleDeferralIsIgnoredWhenTheFeatureIsDisabledMidRun() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1230)
    harness.send(.settingsChanged(quietSettings()))
    #expect(!harness.state.isDeferringForContext)
    harness.run(for: 15)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func settingsReplacementWithADifferentListStopsDeferral() {
    var harness = Harness(settings: deferring())
    harness.send(.context(keynote))
    harness.run(for: 1230)
    var swapped = deferring()
    swapped.deferral.apps = ["us.zoom.xos"]
    harness.send(.settingsChanged(swapped))
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.breakKind == .short)
  }
}
