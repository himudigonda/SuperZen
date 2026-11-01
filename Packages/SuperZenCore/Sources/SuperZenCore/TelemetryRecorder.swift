import Foundation

public struct TelemetryRecorder: Sendable {
  public static let mergeTolerance: TimeInterval = 2
  public static let defaultCheckpoint: TimeInterval = 300

  public private(set) var sessionID: UUID?
  public private(set) var openInterval: ActivityInterval?
  public let checkpoint: TimeInterval
  private let makeID: @Sendable () -> UUID

  public init(
    checkpoint: TimeInterval = TelemetryRecorder.defaultCheckpoint,
    makeID: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.checkpoint = max(1, checkpoint)
    self.makeID = makeID
  }

  public mutating func record(_ event: TelemetryEvent, at now: Date) -> [TelemetryRecord] {
    switch event {
    case .focusStarted:
      if sessionID == nil { sessionID = makeID() }
      return []
    case .focusEnded:
      return endSession()
    case .activeTime(let seconds):
      return extend(.active, by: seconds, endingAt: now)
    case .idleTime(let seconds):
      return extend(.idle, by: seconds, endingAt: now)
    case .breakEnded(let outcome):
      return endSession() + [.breakTaken(Self.breakRecord(outcome, result: outcome.completed ? .completed : .skipped, endingAt: now))]
    case .naturalBreak(let outcome):
      return endSession() + [.breakTaken(Self.breakRecord(outcome, result: .natural, endingAt: now))]
    case .wellnessEnded(let kind, let completed):
      return [.wellness(WellnessRecord(kind: kind, at: now, completed: completed))]
    }
  }

  public mutating func flush() -> [TelemetryRecord] {
    guard let interval = openInterval else { return [] }
    openInterval = nil
    return interval.duration > 0 ? [.activity(interval)] : []
  }

  private mutating func endSession() -> [TelemetryRecord] {
    let records = flush()
    sessionID = nil
    return records
  }

  private mutating func extend(_ kind: ActivityKind, by seconds: TimeInterval, endingAt now: Date) -> [TelemetryRecord] {
    guard seconds.isFinite, seconds > 0 else { return [] }
    let session = sessionID ?? makeID()
    sessionID = session
    let start = now.addingTimeInterval(-seconds)

    if var open = openInterval, open.kind == kind, open.sessionID == session,
      abs(start.timeIntervalSince(open.end)) <= Self.mergeTolerance, now >= open.end
    {
      open.end = now
      openInterval = open
      return open.duration >= checkpoint ? flush() : []
    }

    let closed = flush()
    openInterval = ActivityInterval(sessionID: session, kind: kind, start: start, end: now)
    return closed
  }

  private static func breakRecord(_ outcome: BreakOutcome, result: BreakResult, endingAt now: Date) -> BreakRecord {
    let rested = outcome.rested.isFinite ? max(0, outcome.rested) : 0
    return BreakRecord(
      kind: outcome.kind, result: result, start: now.addingTimeInterval(-rested), end: now, planned: outcome.planned)
  }
}
