import Foundation

@testable import SuperZenCore

extension Calendar {
  static let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()
}

func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
  Calendar.utc.date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

let mondayNoon = utcDate(2026, 11, 2, 12)

struct Harness {
  let engine = SessionEngine(calendar: .utc)
  var state: SessionState
  var now: Date
  var effects: [SessionEffect] = []

  init(settings: Settings = Settings(), at start: Date = mondayNoon) {
    now = start
    let transition = engine.start(settings: settings, at: start)
    state = transition.state
    effects = transition.effects
  }

  var phase: Phase { state.phase }
  var remaining: TimeInterval { state.remaining(at: now) }

  var telemetry: [TelemetryEvent] {
    effects.compactMap {
      if case .telemetry(let event) = $0 { return event }
      return nil
    }
  }

  var breakOutcomes: [BreakOutcome] {
    telemetry.compactMap {
      if case .breakEnded(let outcome) = $0 { return outcome }
      return nil
    }
  }

  var visualEffects: [SessionEffect] {
    effects.filter {
      if case .telemetry = $0 { return false }
      return true
    }
  }

  mutating func send(_ event: SessionEvent) {
    let transition = engine.reduce(state, event, at: now)
    state = transition.state
    effects += transition.effects
  }

  mutating func tick(_ activity: ActivitySample = .present) {
    send(.tick(activity))
  }

  mutating func run(for seconds: TimeInterval, step: TimeInterval = 1, activity: ActivitySample = .present) {
    var elapsed: TimeInterval = 0
    while elapsed < seconds {
      let increment = min(step, seconds - elapsed)
      now = now.addingTimeInterval(increment)
      elapsed += increment
      tick(activity)
    }
  }

  mutating func runIdle(for seconds: TimeInterval, alreadyIdle: TimeInterval = 0) {
    var elapsed: TimeInterval = 0
    while elapsed < seconds {
      now = now.addingTimeInterval(1)
      elapsed += 1
      tick(.away(for: alreadyIdle + elapsed))
    }
  }

  mutating func jump(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }

  mutating func clearEffects() {
    effects.removeAll()
  }
}

extension Phase {
  var isFocus: Bool {
    if case .focus = self { return true }
    return false
  }

  var isNudge: Bool {
    if case .nudge = self { return true }
    return false
  }

  var breakKind: BreakKind? {
    if case .onBreak(let session) = self { return session.kind }
    return nil
  }

  var isNaturalBreak: Bool {
    if case .naturalBreak = self { return true }
    return false
  }

  var pauseReason: PauseReason? {
    if case .paused(let pause) = self { return pause.reason }
    return nil
  }

  var wellnessKind: WellnessKind? {
    if case .wellness(let pulse) = self { return pulse.kind }
    return nil
  }
}

func quietSettings() -> Settings {
  var settings = Settings()
  for kind in WellnessKind.allCases { settings.wellness[kind].enabled = false }
  return settings
}
