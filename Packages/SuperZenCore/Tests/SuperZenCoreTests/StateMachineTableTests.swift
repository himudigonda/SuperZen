import Foundation
import Testing

@testable import SuperZenCore

enum PhaseSetup: String, CaseIterable, Sendable {
  case focus, nudge, wellness, naturalBreak, shortBreak, longBreak, userPause, schedulePause, systemPause

  func build() -> Harness {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 2
    var harness: Harness
    switch self {
    case .focus:
      harness = Harness(settings: settings)
      harness.run(for: 60)
    case .nudge:
      harness = Harness(settings: settings)
      harness.run(for: 1195)
    case .wellness:
      settings.wellness.blink = Reminder(enabled: true, interval: 60)
      harness = Harness(settings: settings)
      harness.run(for: 60)
    case .naturalBreak:
      harness = Harness(settings: settings)
      harness.run(for: 60)
      harness.runIdle(for: 150)
    case .shortBreak:
      harness = Harness(settings: settings)
      harness.run(for: 1200)
    case .longBreak:
      harness = Harness(settings: settings)
      harness.state.cyclesSinceLongBreak = 1
      harness.run(for: 1200)
    case .userPause:
      harness = Harness(settings: settings)
      harness.run(for: 60)
      harness.send(.togglePause)
    case .schedulePause:
      settings.schedule.enabled = true
      settings.schedule.window = TimeWindow(startMinute: 0, endMinute: 600)
      settings.schedule.weekdays = [2]
      harness = Harness(settings: settings)
      harness.run(for: 10)
    case .systemPause:
      harness = Harness(settings: settings)
      harness.run(for: 60)
      harness.send(.suspend(.sleep))
    }
    harness.clearEffects()
    return harness
  }

  var expectedPhaseName: String {
    switch self {
    case .focus: return "focus"
    case .nudge: return "nudge"
    case .wellness: return "wellness"
    case .naturalBreak: return "naturalBreak"
    case .shortBreak, .longBreak: return "onBreak"
    case .userPause, .schedulePause, .systemPause: return "paused"
    }
  }
}

extension Phase {
  var name: String {
    switch self {
    case .focus: return "focus"
    case .nudge: return "nudge"
    case .wellness: return "wellness"
    case .naturalBreak: return "naturalBreak"
    case .onBreak: return "onBreak"
    case .paused: return "paused"
    }
  }
}

@Suite struct StateMachineTableTests {
  @Test(arguments: PhaseSetup.allCases)
  func setupLandsInTheNamedPhase(setup: PhaseSetup) {
    let harness = setup.build()
    #expect(harness.phase.name == setup.expectedPhaseName, "phase \(harness.phase)")
    if setup == .longBreak { #expect(harness.phase.breakKind == .long) }
    if setup == .userPause { #expect(harness.phase.pauseReason == .user) }
    if setup == .schedulePause { #expect(harness.phase.pauseReason == .schedule) }
    if setup == .systemPause { #expect(harness.phase.pauseReason == .system) }
  }

  @Test(arguments: PhaseSetup.allCases)
  func everyEventKeepsTheStateSound(setup: PhaseSetup) {
    var settings = quietSettings()
    settings.timer.workDuration = 90
    let events: [SessionEvent] = [
      .tick(.present), .tick(.typing), .tick(.away(for: 500)), .suspend(.sleep), .suspend(.screenLock),
      .resume(.sleep), .resume(.sessionSwitch), .settingsChanged(settings), .settingsChanged(Settings()),
      .startBreak, .skipBreak, .snooze(nil), .snooze(30), .snooze(-1), .snooze(0), .extendBreak(10),
      .extendBreak(-10), .extendBreak(0), .togglePause, .togglePause,
    ]
    for event in events {
      var harness = setup.build()
      harness.jump(by: 1)
      harness.send(event)
      harness.jump(by: 1)
      harness.tick()
      let remaining = harness.remaining
      #expect(remaining.isFinite && remaining >= 0, "\(setup) \(event) remaining \(remaining)")
      let snapshot = MenuBarSnapshot(state: harness.state, at: harness.now)
      #expect((0...1).contains(snapshot.progress), "\(setup) \(event) progress \(snapshot.progress)")
    }
  }

  @Test(arguments: PhaseSetup.allCases.filter { $0 != .nudge })
  func snoozeOutsideANudgeChangesNothing(setup: PhaseSetup) {
    var harness = setup.build()
    let before = harness.state.phase
    harness.send(.snooze(60))
    #expect(harness.phase == before)
    #expect(harness.effects.isEmpty)
  }

  @Test(arguments: PhaseSetup.allCases.filter { $0 != .shortBreak && $0 != .longBreak })
  func extendOutsideABreakChangesNothing(setup: PhaseSetup) {
    var harness = setup.build()
    let before = harness.state.phase
    harness.send(.extendBreak(30))
    #expect(harness.phase == before)
    #expect(harness.effects.isEmpty)
  }

  @Test(arguments: [PhaseSetup.userPause, .schedulePause, .systemPause, .focus, .naturalBreak, .wellness])
  func skipOutsideABreakOrNudgeChangesNothing(setup: PhaseSetup) {
    var harness = setup.build()
    let before = harness.state.phase
    harness.send(.skipBreak)
    #expect(harness.phase == before)
    #expect(harness.effects.isEmpty)
  }

  @Test func snoozeDuringNudgePushesTheDeadlineByTheSnoozeLength() {
    var harness = PhaseSetup.nudge.build()
    let deadline = harness.now.addingTimeInterval(harness.remaining)
    harness.send(.snooze(60))
    #expect(harness.phase.isFocus)
    #expect(abs(harness.remaining - (deadline.timeIntervalSince(harness.now) + 60)) < 0.001)
  }

  @Test func startBreakWhileSystemPausedIsIgnored() {
    var harness = PhaseSetup.systemPause.build()
    harness.send(.startBreak)
    #expect(harness.phase.pauseReason == .system)
  }

  @Test func togglePauseWhileSystemPausedIsIgnored() {
    var harness = PhaseSetup.systemPause.build()
    harness.send(.togglePause)
    #expect(harness.phase.pauseReason == .system)
  }

  @Test func everyThirdBreakIsLongAndTheCycleRestarts() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 3
    var harness = Harness(settings: settings)
    var kinds: [BreakKind] = []
    for _ in 0..<7 {
      while harness.phase.breakKind == nil { harness.run(for: 1) }
      if let kind = harness.phase.breakKind { kinds.append(kind) }
      while harness.phase.breakKind != nil { harness.run(for: 1) }
    }
    #expect(kinds == [.short, .short, .long, .short, .short, .long, .short])
  }

  @Test func changingLongBreakEveryMidCycleStillOffersALongBreakWhenDue() {
    var settings = quietSettings()
    settings.timer.longBreakEvery = 10
    var harness = Harness(settings: settings)
    harness.run(for: 1200)
    harness.run(for: 30)
    harness.run(for: 1200)
    #expect(harness.state.cyclesSinceLongBreak == 2)
    settings.timer.longBreakEvery = 2
    harness.send(.settingsChanged(settings))
    #expect(harness.state.nextBreakKind == .long)
  }
}
