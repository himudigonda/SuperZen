import Foundation

public enum MenuBarGlyph: String, CaseIterable, Sendable {
  case focusing
  case breakSoon
  case typing
  case shortBreak
  case longBreak
  case wellness
  case paused
  case scheduleSleep
}

public struct MenuBarActions: Equatable, Sendable {
  public var canStartBreak: Bool
  public var canSkip: Bool
  public var canSnooze: Bool
  public var skipUnlocksIn: Int

  public init(canStartBreak: Bool, canSkip: Bool, canSnooze: Bool, skipUnlocksIn: Int) {
    self.canStartBreak = canStartBreak
    self.canSkip = canSkip
    self.canSnooze = canSnooze
    self.skipUnlocksIn = skipUnlocksIn
  }

  public static let none = MenuBarActions(canStartBreak: false, canSkip: false, canSnooze: false, skipUnlocksIn: 0)

  public init(state: SessionState, at now: Date) {
    let hardcore = state.settings.skipPolicy.difficulty == .hardcore
    switch state.phase {
    case .onBreak:
      self.init(
        canStartBreak: false, canSkip: state.canSkip(at: now), canSnooze: false,
        skipUnlocksIn: hardcore ? 0 : Int.saturating(state.skipLockRemaining(at: now).rounded(.up)))
    case .nudge:
      self.init(canStartBreak: true, canSkip: !hardcore, canSnooze: true, skipUnlocksIn: 0)
    case .paused(let pause):
      self.init(canStartBreak: pause.reason != .system, canSkip: false, canSnooze: false, skipUnlocksIn: 0)
    case .focus, .naturalBreak, .wellness:
      self.init(canStartBreak: true, canSkip: false, canSnooze: false, skipUnlocksIn: 0)
    }
  }
}

public struct MenuBarSnapshot: Equatable, Sendable {
  public var glyph: MenuBarGlyph
  public var remaining: TimeInterval
  public var progress: Double
  public var nextBreakAt: Date?
  public var nextBreakKind: BreakKind
  public var currentBreakKind: BreakKind?
  public var actions: MenuBarActions
  public var deferredByApp: Bool

  public init(
    glyph: MenuBarGlyph, remaining: TimeInterval, progress: Double, nextBreakAt: Date?,
    nextBreakKind: BreakKind, currentBreakKind: BreakKind?, actions: MenuBarActions = .none,
    deferredByApp: Bool = false
  ) {
    self.glyph = glyph
    self.remaining = remaining
    self.progress = progress
    self.nextBreakAt = nextBreakAt
    self.nextBreakKind = nextBreakKind
    self.currentBreakKind = currentBreakKind
    self.actions = actions
    self.deferredByApp = deferredByApp
  }

  public static let initial = MenuBarSnapshot(
    glyph: .focusing, remaining: 0, progress: 0, nextBreakAt: nil, nextBreakKind: .short,
    currentBreakKind: nil)

  public init(state: SessionState, at now: Date) {
    let remaining = state.remaining(at: now)
    self.init(
      glyph: Self.glyph(for: state),
      remaining: remaining,
      progress: Self.progress(of: state, at: now),
      nextBreakAt: Self.isCountingDown(state.phase) ? now.addingTimeInterval(remaining) : nil,
      nextBreakKind: state.nextBreakKind,
      currentBreakKind: state.currentBreak?.kind,
      actions: MenuBarActions(state: state, at: now),
      deferredByApp: state.isDeferringForContext)
  }

  public var isPaused: Bool { glyph == .paused || glyph == .scheduleSleep }
  public var isOnBreak: Bool { currentBreakKind != nil }

  static func glyph(for state: SessionState) -> MenuBarGlyph {
    switch state.phase {
    case .focus, .naturalBreak: return .focusing
    case .nudge: return state.isTyping ? .typing : .breakSoon
    case .onBreak(let session): return session.kind == .long ? .longBreak : .shortBreak
    case .wellness: return .wellness
    case .paused(let pause): return pause.reason == .schedule ? .scheduleSleep : .paused
    }
  }

  static func progress(of state: SessionState, at now: Date) -> Double {
    let work = state.settings.timer.workDuration
    switch state.phase {
    case .focus(let block), .nudge(let block):
      return fraction(work - block.remaining(at: now), of: work)
    case .wellness(let pulse):
      return fraction(work - pulse.focus.remaining(at: now), of: work)
    case .naturalBreak:
      return 0
    case .onBreak(let session):
      return fraction(session.elapsed(at: now), of: session.planned)
    case .paused(let pause):
      switch pause.resume {
      case .focus(let remaining): return fraction(work - remaining, of: work)
      case .naturalBreak: return 0
      case .onBreak(let session): return fraction(session.elapsedBeforeResume, of: session.planned)
      }
    }
  }

  static func isCountingDown(_ phase: Phase) -> Bool {
    switch phase {
    case .focus, .nudge, .wellness: return true
    case .naturalBreak, .onBreak, .paused: return false
    }
  }

  static func fraction(_ part: TimeInterval, of whole: TimeInterval) -> Double {
    guard whole > 0, part.isFinite else { return 0 }
    return min(1, max(0, part / whole))
  }
}

public enum TimerStyle: String, CaseIterable, Sendable {
  case clock = "15:11"
  case minutes = "15m"
  case bare = "15"

  public func format(_ remaining: TimeInterval) -> String {
    let seconds = max(0, Int.saturating(remaining.rounded(.up)))
    switch self {
    case .clock: return String(format: "%d:%02d", seconds / 60, seconds % 60)
    case .minutes: return "\(Self.minutesRoundedUp(seconds))m"
    case .bare: return "\(Self.minutesRoundedUp(seconds))"
    }
  }

  static func minutesRoundedUp(_ seconds: Int) -> Int {
    (seconds + 59) / 60
  }
}

public enum DayProgressMetric: String, CaseIterable, Sendable {
  case percentDone = "pct_done"
  case percentRemaining = "pct_remaining"
  case minutesElapsed = "min_elapsed"
  case minutesRemaining = "min_remaining"
  case hoursElapsed = "hr_elapsed"
  case hoursRemaining = "hr_remaining"
  case timeElapsed = "hr_min_elapsed"
  case timeRemaining = "hr_min_remaining"

  public func label(for progress: DayProgress) -> String {
    let doneMinutes = max(0, Int.saturating(progress.elapsed)) / 60
    let leftMinutes = (max(0, Int.saturating(progress.remaining.rounded(.up))) + 59) / 60
    let donePercent = Int.saturating(min(1, max(0, progress.fraction)) * 100)
    switch self {
    case .percentDone: return "\(donePercent)%"
    case .percentRemaining: return "\(100 - donePercent)%"
    case .minutesElapsed: return "\(doneMinutes)m"
    case .minutesRemaining: return "\(leftMinutes)m"
    case .hoursElapsed: return "\(doneMinutes / 60)h"
    case .hoursRemaining: return "\(max(0, Int.saturating(progress.remaining)) / 3600)h"
    case .timeElapsed: return Self.hoursAndMinutes(doneMinutes)
    case .timeRemaining: return Self.hoursAndMinutes(leftMinutes)
    }
  }

  static func hoursAndMinutes(_ totalMinutes: Int) -> String {
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return "\(minutes)m" }
    return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
  }
}
