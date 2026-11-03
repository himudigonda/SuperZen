import Foundation
import Testing

@testable import SuperZenCore

struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var mixed = state
    mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
    mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
    return mixed ^ (mixed >> 31)
  }
}

private struct EffectLedger {
  var overlayVisible = false
  var focusOpen = false

  mutating func apply(_ effects: [SessionEffect]) {
    for effect in effects {
      switch effect {
      case .showNudge, .showBreak, .showWellness: overlayVisible = true
      case .hideOverlays: overlayVisible = false
      case .telemetry(.focusStarted): focusOpen = true
      case .telemetry(.focusEnded): focusOpen = false
      default: break
      }
    }
  }
}

private func randomSettings(_ generator: inout SeededGenerator) -> Settings {
  var settings = Settings()
  settings.timer.workDuration = Double.random(in: 5...120, using: &generator)
  settings.timer.shortBreakDuration = Double.random(in: 1...30, using: &generator)
  settings.timer.longBreakDuration = Double.random(in: 1...60, using: &generator)
  settings.timer.longBreakEvery = Int.random(in: 0...4, using: &generator)
  settings.timer.nudgeLeadTime = Double.random(in: 0...20, using: &generator)
  settings.timer.typingDeferralCap = Double.random(in: 0...30, using: &generator)
  settings.timer.naturalBreakMinimum = Double.random(in: 0...60, using: &generator)
  settings.timer.idleThreshold = Double.random(in: 1...15, using: &generator)
  settings.timer.deferWhileTyping = Bool.random(using: &generator)
  settings.timer.resetFocusAfterBreak = Bool.random(using: &generator)
  settings.timer.maxPostpones = Int.random(in: 0...3, using: &generator)
  settings.timer.snoozeDuration = Double.random(in: 1...60, using: &generator)
  settings.plannedBreaks = (0..<Int.random(in: 0...3, using: &generator)).map { index in
    PlannedBreak(
      id: "planned-\(index)", minuteOfDay: Int.random(in: 0..<1440, using: &generator),
      weekdays: Set((1...7).filter { _ in Bool.random(using: &generator) }),
      duration: Double.random(in: 1...30, using: &generator))
  }
  settings.skipPolicy.difficulty = BreakDifficulty.allCases.randomElement(using: &generator) ?? .balanced
  for kind in WellnessKind.allCases {
    settings.wellness[kind].enabled = Bool.random(using: &generator)
    settings.wellness[kind].interval = Double.random(in: 3...50, using: &generator)
  }
  settings.schedule.enabled = Int.random(in: 0...3, using: &generator) == 0
  settings.schedule.window = TimeWindow(
    startMinute: Int.random(in: 0..<1440, using: &generator), endMinute: Int.random(in: 0..<1440, using: &generator))
  settings.schedule.weekdays = Set((1...7).filter { _ in Bool.random(using: &generator) })
  settings.schedule.autoResume = Bool.random(using: &generator)
  settings.quietHours.enabled = Bool.random(using: &generator)
  settings.quietHours.window = TimeWindow(
    startMinute: Int.random(in: 0..<1440, using: &generator), endMinute: Int.random(in: 0..<1440, using: &generator))
  return settings
}

private func randomActivity(_ generator: inout SeededGenerator) -> ActivitySample {
  switch Int.random(in: 0..<5, using: &generator) {
  case 0: return .typing
  case 1: return .away(for: Double.random(in: 0...200, using: &generator))
  default: return .present
  }
}

private func randomEvent(_ generator: inout SeededGenerator) -> SessionEvent {
  switch Int.random(in: 0..<24, using: &generator) {
  case 0: return .suspend(SuspendCause.allCases.randomElement(using: &generator) ?? .sleep)
  case 1, 2: return .resume(SuspendCause.allCases.randomElement(using: &generator) ?? .sleep)
  case 3: return .settingsChanged(randomSettings(&generator))
  case 4: return .startBreak
  case 5: return .skipBreak
  case 6: return .snooze(Bool.random(using: &generator) ? nil : Double.random(in: -5...60, using: &generator))
  case 7: return .extendBreak(Double.random(in: -5...30, using: &generator))
  case 8: return .togglePause
  case 9, 10: return .postpone(Bool.random(using: &generator) ? nil : Double.random(in: -5...90, using: &generator))
  case 11:
    switch Int.random(in: 0..<4, using: &generator) {
    case 0: return .pause(for: nil)
    case 1: return .pause(for: .nan)
    default: return .pause(for: Double.random(in: -5...400, using: &generator))
    }
  default: return .tick(randomActivity(&generator))
  }
}

private func randomJump(_ generator: inout SeededGenerator) -> TimeInterval {
  switch Int.random(in: 0..<14, using: &generator) {
  case 0: return 0
  case 2: return -Double.random(in: 0...100_000, using: &generator)
  case 1: return Double.random(in: 91...200_000, using: &generator)
  default: return Double.random(in: 0...6, using: &generator)
  }
}

@Suite struct EngineInvariantTests {
  @Test(arguments: Array(1...60))
  func randomSequencesKeepTheStateSound(seed: Int) {
    var generator = SeededGenerator(state: UInt64(seed))
    var harness = Harness(settings: randomSettings(&generator), at: mondayNoon)
    var ledger = EffectLedger()
    ledger.apply(harness.effects)
    var history: [String] = []

    for step in 0..<400 {
      harness.jump(by: randomJump(&generator))
      let event = randomEvent(&generator)
      history.append("\(step): \(event)")
      let before = harness.effects.count
      harness.send(event)
      ledger.apply(Array(harness.effects[before...]))
      let context = "seed \(seed) step \(step) after \(event) phase \(harness.phase)\nlast: \(history.suffix(6))"

      let remaining = harness.remaining
      #expect(remaining.isFinite && remaining >= 0, "remaining \(remaining) \(context)")
      let snapshot = MenuBarSnapshot(state: harness.state, at: harness.now)
      #expect((0...1).contains(snapshot.progress), "progress \(snapshot.progress) \(context)")

      let showsOverlay: Bool
      switch harness.phase {
      case .nudge, .onBreak, .wellness: showsOverlay = true
      default: showsOverlay = false
      }
      #expect(ledger.overlayVisible == showsOverlay, "overlay ledger \(context)")
      #expect(ledger.focusOpen == harness.state.hasOpenFocusSession, "focus ledger \(context)")

      #expect(harness.state.postponesUsed >= 0, "postponesUsed \(context)")
      #expect(harness.state.cyclesSinceLongBreak >= 0, "cycles \(context)")
      if case .paused(let pause) = harness.phase, let until = pause.until {
        #expect(pause.reason == .user && until.timeIntervalSinceReferenceDate.isFinite, "pause until \(context)")
      }
      if harness.state.suspensions.isEmpty {
        #expect(harness.phase.pauseReason != .system, "stuck system pause \(context)")
      }
      if case .onBreak(let session) = harness.phase {
        #expect(session.planned >= 1 && session.planned <= Settings.maximumDuration, "planned \(context)")
      }
    }
  }
}
