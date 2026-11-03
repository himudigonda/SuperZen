import Foundation

public enum BreakKind: String, CaseIterable, Codable, Sendable {
  case short
  case long
}

public enum SuspendCause: String, CaseIterable, Codable, Sendable {
  case sleep
  case screenLock
  case sessionSwitch
}

public enum PauseReason: String, Codable, Sendable {
  case user
  case schedule
  case system
}

public struct ActivitySample: Equatable, Sendable {
  public static let typingWindow: TimeInterval = 5

  public var secondsSinceInput: TimeInterval
  public var secondsSinceKeyboard: TimeInterval

  public init(secondsSinceInput: TimeInterval, secondsSinceKeyboard: TimeInterval) {
    self.secondsSinceInput = max(0, secondsSinceInput)
    self.secondsSinceKeyboard = max(0, secondsSinceKeyboard)
  }

  public static let present = ActivitySample(secondsSinceInput: 0, secondsSinceKeyboard: .infinity)
  public static let typing = ActivitySample(secondsSinceInput: 0, secondsSinceKeyboard: 0)

  public static func away(for seconds: TimeInterval) -> ActivitySample {
    ActivitySample(secondsSinceInput: seconds, secondsSinceKeyboard: seconds)
  }

  public var isTyping: Bool { secondsSinceKeyboard < Self.typingWindow }
}

public struct FocusBlock: Equatable, Sendable {
  public var deadline: Date
  public var startedAt: Date?
  public var typingDeferralStartedAt: Date?
  public var contextDeferralStartedAt: Date?

  public init(
    deadline: Date, startedAt: Date? = nil, typingDeferralStartedAt: Date? = nil, contextDeferralStartedAt: Date? = nil
  ) {
    self.deadline = deadline
    self.startedAt = startedAt
    self.typingDeferralStartedAt = typingDeferralStartedAt
    self.contextDeferralStartedAt = contextDeferralStartedAt
  }

  public func remaining(at now: Date) -> TimeInterval {
    max(0, deadline.timeIntervalSince(now))
  }
}

public struct BreakSession: Equatable, Sendable {
  public var kind: BreakKind
  public var planned: TimeInterval
  public var elapsedBeforeResume: TimeInterval
  public var resumedAt: Date
  public var focusRemainingBeforeBreak: TimeInterval?
  public var cyclesBeforeBreak: Int

  public init(
    kind: BreakKind,
    planned: TimeInterval,
    startedAt: Date,
    focusRemainingBeforeBreak: TimeInterval? = nil,
    cyclesBeforeBreak: Int = 0
  ) {
    self.kind = kind
    self.planned = planned
    self.elapsedBeforeResume = 0
    self.resumedAt = startedAt
    self.focusRemainingBeforeBreak = focusRemainingBeforeBreak
    self.cyclesBeforeBreak = cyclesBeforeBreak
  }

  public var deadline: Date { resumedAt.addingTimeInterval(planned - elapsedBeforeResume) }

  public func elapsed(at now: Date) -> TimeInterval {
    max(0, elapsedBeforeResume + now.timeIntervalSince(resumedAt))
  }

  public func remaining(at now: Date) -> TimeInterval {
    max(0, deadline.timeIntervalSince(now))
  }

  func frozen(at now: Date) -> BreakSession {
    var copy = self
    copy.elapsedBeforeResume = min(planned, elapsed(at: now))
    copy.resumedAt = now
    return copy
  }

  func resumed(at now: Date) -> BreakSession {
    var copy = self
    copy.resumedAt = now
    return copy
  }
}

public struct WellnessPulse: Equatable, Sendable {
  public var kind: WellnessKind
  public var endsAt: Date
  public var focus: FocusBlock

  public init(kind: WellnessKind, endsAt: Date, focus: FocusBlock) {
    self.kind = kind
    self.endsAt = endsAt
    self.focus = focus
  }
}

public enum ResumePoint: Equatable, Sendable {
  case focus(remaining: TimeInterval)
  case naturalBreak(since: Date)
  case onBreak(BreakSession)
}

public struct Pause: Equatable, Sendable {
  public var reason: PauseReason
  public var since: Date
  public var awaySince: Date
  public var resume: ResumePoint
  public var until: Date?

  public init(reason: PauseReason, since: Date, resume: ResumePoint, awaySince: Date? = nil, until: Date? = nil) {
    self.reason = reason
    self.since = since
    self.awaySince = awaySince?.clamped(notAfter: since) ?? since
    self.resume = resume
    self.until = until
  }
}

public enum Phase: Equatable, Sendable {
  case focus(FocusBlock)
  case nudge(FocusBlock)
  case naturalBreak(since: Date)
  case onBreak(BreakSession)
  case wellness(WellnessPulse)
  case paused(Pause)
}

public enum SessionEvent: Equatable, Sendable {
  case tick(ActivitySample)
  case suspend(SuspendCause)
  case resume(SuspendCause)
  case settingsChanged(Settings)
  case startBreak
  case skipBreak
  case snooze(TimeInterval?)
  case extendBreak(TimeInterval)
  case togglePause
  case pause(for: TimeInterval?)
  case postpone(TimeInterval?)
  case context(ContextSample)
}

public enum SoundCue: String, Sendable {
  case breakStart
  case breakEnd
  case nudge
}

public struct BreakOutcome: Equatable, Sendable {
  public var kind: BreakKind
  public var completed: Bool
  public var rested: TimeInterval
  public var planned: TimeInterval
  public var postponed: Bool

  public init(kind: BreakKind, completed: Bool, rested: TimeInterval, planned: TimeInterval, postponed: Bool = false) {
    self.kind = kind
    self.completed = completed
    self.rested = rested
    self.planned = planned
    self.postponed = postponed
  }
}

public enum TelemetryEvent: Equatable, Sendable {
  case focusStarted
  case focusEnded
  case activeTime(TimeInterval)
  case idleTime(TimeInterval)
  case breakEnded(BreakOutcome)
  case naturalBreak(BreakOutcome)
  case wellnessEnded(WellnessKind, completed: Bool)
}

public enum SessionEffect: Equatable, Sendable {
  case showNudge
  case showBreak(BreakKind)
  case showWellness(WellnessKind, duration: TimeInterval)
  case hideOverlays
  case play(SoundCue)
  case telemetry(TelemetryEvent)
}

public struct Transition: Equatable, Sendable {
  public var state: SessionState
  public var effects: [SessionEffect]

  public init(state: SessionState, effects: [SessionEffect]) {
    self.state = state
    self.effects = effects
  }
}
