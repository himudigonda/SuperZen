import Foundation
import Testing

@testable import SuperZenCore

@Suite struct ScheduleEngineTests {
  private func scheduled(autoResume: Bool = true) -> Settings {
    var settings = quietSettings()
    settings.schedule.enabled = true
    settings.schedule.window = TimeWindow(startMinute: 540, endMinute: 1080)
    settings.schedule.autoResume = autoResume
    return settings
  }

  @Test func leavingScheduleSleepsAndClosesFocusSession() {
    var harness = Harness(settings: scheduled(), at: utcDate(2026, 11, 2, 17, 59))
    harness.run(for: 60)
    #expect(harness.phase.pauseReason == .schedule)
    #expect(harness.state.isScheduleSleeping)
    #expect(harness.telemetry.contains(.focusEnded))
  }

  @Test func autoResumesWithFreshFocusWhenScheduleStarts() {
    var harness = Harness(settings: scheduled(), at: utcDate(2026, 11, 2, 17, 59))
    harness.run(for: 60)
    harness.now = utcDate(2026, 11, 3, 9, 0)
    harness.tick()
    #expect(harness.phase.isFocus)
    #expect(harness.remaining == 1200)
  }

  @Test func staysAsleepWithoutAutoResume() {
    var harness = Harness(settings: scheduled(autoResume: false), at: utcDate(2026, 11, 2, 17, 59))
    harness.run(for: 60)
    harness.now = utcDate(2026, 11, 3, 9, 0)
    harness.tick()
    #expect(harness.phase.pauseReason == .schedule)
  }

  @Test func manualResumeOverridesScheduleUntilNextWindow() {
    var harness = Harness(settings: scheduled(), at: utcDate(2026, 11, 2, 17, 59))
    harness.run(for: 60)
    harness.send(.togglePause)
    harness.run(for: 30)
    #expect(harness.phase.isFocus)
    harness.now = utcDate(2026, 11, 3, 12, 0)
    harness.tick()
    harness.now = utcDate(2026, 11, 3, 18, 0)
    harness.tick()
    #expect(harness.phase.pauseReason == .schedule)
  }

  @Test func scheduleNeverInterruptsBreak() {
    var harness = Harness(settings: scheduled(), at: utcDate(2026, 11, 2, 17, 59, 50))
    harness.send(.startBreak)
    harness.run(for: 15)
    #expect(harness.phase.breakKind == .short)
  }

  @Test func weekendIsOutsideSchedule() {
    var harness = Harness(settings: scheduled(), at: utcDate(2026, 11, 7, 12))
    harness.tick()
    #expect(harness.phase.pauseReason == .schedule)
  }

  @Test func disablingScheduleWakesEvenWithoutAutoResume() {
    var settings = scheduled(autoResume: false)
    var harness = Harness(settings: settings, at: utcDate(2026, 11, 7, 12))
    harness.tick()
    settings.schedule.enabled = false
    harness.send(.settingsChanged(settings))
    harness.tick()
    #expect(harness.phase.isFocus)
  }
}

@Suite struct WellnessEngineTests {
  private func longFocus() -> Settings {
    var settings = Settings()
    settings.timer.workDuration = 7200
    return settings
  }

  @Test func reminderFiresAtIntervalWithoutTouchingFocusDeadline() {
    var harness = Harness(settings: longFocus())
    harness.run(for: 1199)
    #expect(harness.phase.isFocus)
    harness.clearEffects()
    harness.run(for: 1)
    #expect(harness.phase.wellnessKind == .posture)
    #expect(harness.visualEffects == [.showWellness(.posture, duration: 0.75), .play(.nudge)])
    harness.run(for: 1)
    #expect(harness.telemetry.contains(.wellnessEnded(.posture, completed: true)))
    #expect(harness.remaining == 7200 - 1201)
  }

  @Test func simultaneousRemindersFireOneAtATimeInOrder() {
    var harness = Harness(settings: longFocus())
    var fired: [WellnessKind] = []
    for _ in 0..<1205 {
      harness.run(for: 1)
      if let kind = harness.phase.wellnessKind, fired.last != kind { fired.append(kind) }
    }
    #expect(fired == [.posture, .blink])
  }

  @Test func typingDefersReminderUpToTheCap() {
    var harness = Harness(settings: longFocus())
    var firedAt: TimeInterval?
    for second in 1...1400 {
      harness.run(for: 1, activity: .typing)
      if firedAt == nil, harness.phase.wellnessKind != nil { firedAt = TimeInterval(second) }
    }
    #expect(firedAt == 1320)
  }

  @Test func quietHoursHoldRemindersUntilTheyEnd() {
    var settings = longFocus()
    settings.quietHours.enabled = true
    var harness = Harness(settings: settings, at: utcDate(2026, 11, 2, 6, 30))
    var firstFire: Date?
    for _ in 0..<3000 {
      harness.run(for: 1)
      if firstFire == nil, harness.phase.wellnessKind != nil { firstFire = harness.now }
    }
    #expect(firstFire == utcDate(2026, 11, 2, 7, 19, 59))
  }

  @Test func disabledReminderNeverFires() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1150)
    #expect(!harness.visualEffects.contains { if case .showWellness = $0 { return true } else { return false } })
    #expect(harness.state.wellnessDue.isEmpty)
  }

  @Test func changingIntervalReschedulesFromNow() {
    var settings = longFocus()
    var harness = Harness(settings: settings)
    harness.run(for: 100)
    settings.wellness.posture.interval = 60
    harness.send(.settingsChanged(settings))
    #expect(harness.state.wellnessDue[.posture] == harness.now.addingTimeInterval(60))
  }

  @Test func multiplierScalesPulseDuration() {
    var settings = longFocus()
    settings.wellness.durationMultiplier = 2
    var harness = Harness(settings: settings)
    harness.run(for: 1200)
    #expect(harness.effects.contains(.showWellness(.posture, duration: 1.5)))
  }

  @Test func pauseDuringPulseLogsDismissal() {
    var harness = Harness(settings: longFocus())
    harness.run(for: 1200)
    harness.send(.togglePause)
    #expect(harness.telemetry.contains(.wellnessEnded(.posture, completed: false)))
    #expect(harness.remaining == 6000)
  }
}

@Suite struct SettingsChangeTests {
  @Test func workDurationChangeRestartsFocus() {
    var settings = quietSettings()
    var harness = Harness(settings: settings)
    harness.run(for: 300)
    settings.timer.workDuration = 600
    harness.send(.settingsChanged(settings))
    #expect(harness.remaining == 600)
  }

  @Test func breakDurationChangeRestartsMatchingBreak() {
    var settings = quietSettings()
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    harness.run(for: 5)
    settings.timer.shortBreakDuration = 60
    harness.send(.settingsChanged(settings))
    #expect(harness.remaining == 60)
  }

  @Test func workDurationChangeWhilePausedUpdatesResumePoint() {
    var settings = quietSettings()
    var harness = Harness(settings: settings)
    harness.send(.togglePause)
    settings.timer.workDuration = 1500
    harness.send(.settingsChanged(settings))
    harness.send(.togglePause)
    #expect(harness.remaining == 1500)
  }

  @Test func identicalSettingsAreANoOp() {
    var harness = Harness(settings: quietSettings())
    harness.clearEffects()
    let before = harness.state
    harness.send(.settingsChanged(quietSettings()))
    #expect(harness.state == before)
    #expect(harness.effects.isEmpty)
  }

  @Test func difficultyChangeAppliesToRunningBreak() {
    var settings = quietSettings()
    var harness = Harness(settings: settings)
    harness.send(.startBreak)
    #expect(harness.state.canSkip(at: harness.now) == false)
    settings.skipPolicy.difficulty = .casual
    harness.send(.settingsChanged(settings))
    #expect(harness.state.canSkip(at: harness.now))
  }
}
