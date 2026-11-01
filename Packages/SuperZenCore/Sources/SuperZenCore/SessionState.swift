import Foundation

public struct SessionState: Equatable, Sendable {
  public internal(set) var settings: Settings
  public internal(set) var phase: Phase
  public internal(set) var cyclesSinceLongBreak: Int = 0
  public internal(set) var wellnessDue: [WellnessKind: Date] = [:]
  public internal(set) var lastTick: Date?
  public internal(set) var continuousActive: TimeInterval = 0
  public internal(set) var suspensions: Set<SuspendCause> = []
  public internal(set) var scheduleOverride = false
  public internal(set) var isTyping = false

  init(settings: Settings, phase: Phase) {
    self.settings = settings
    self.phase = phase
  }

  public var nextBreakKind: BreakKind {
    let every = settings.timer.longBreakEvery
    return every > 0 && cyclesSinceLongBreak + 1 >= every ? .long : .short
  }

  public var isScheduleSleeping: Bool {
    if case .paused(let pause) = phase { return pause.reason == .schedule }
    return false
  }

  public var isPaused: Bool {
    if case .paused = phase { return true }
    return false
  }

  public var isDeferringForTyping: Bool {
    if case .nudge(let block) = phase { return block.typingDeferralStartedAt != nil }
    return false
  }

  public var currentBreak: BreakSession? {
    if case .onBreak(let session) = phase { return session }
    return nil
  }

  public func remaining(at now: Date) -> TimeInterval {
    switch phase {
    case .focus(let block), .nudge(let block):
      return block.remaining(at: now)
    case .wellness(let pulse):
      return pulse.focus.remaining(at: now)
    case .naturalBreak:
      return settings.timer.workDuration
    case .onBreak(let session):
      return session.remaining(at: now)
    case .paused(let pause):
      switch pause.resume {
      case .focus(let remaining): return remaining
      case .onBreak(let session): return session.remaining(at: session.resumedAt)
      }
    }
  }

  public func canSkip(at now: Date) -> Bool {
    switch settings.skipPolicy.difficulty {
    case .casual: return true
    case .hardcore: return false
    case .balanced: return skipLockRemaining(at: now) <= 0
    }
  }

  public func skipLockRemaining(at now: Date) -> TimeInterval {
    guard let session = currentBreak else { return 0 }
    let lock = settings.skipPolicy.lockDuration(forBreakOf: session.planned)
    return max(0, lock - session.elapsed(at: now))
  }
}
