import Foundation

public enum ActivityKind: String, CaseIterable, Codable, Sendable {
  case active
  case idle
}

public struct ActivityInterval: Equatable, Sendable {
  public static let maximumSpan: TimeInterval = 7 * 86_400

  public var sessionID: UUID
  public var kind: ActivityKind
  public var start: Date
  public var end: Date

  public init(sessionID: UUID, kind: ActivityKind, start: Date, end: Date) {
    self.sessionID = sessionID
    self.kind = kind
    self.start = start
    self.end = max(start, end)
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }

  public func overlap(with interval: DateInterval) -> TimeInterval {
    let lower = max(start, interval.start)
    let upper = min(end, interval.end)
    return max(0, upper.timeIntervalSince(lower))
  }
}

public enum BreakResult: String, CaseIterable, Codable, Sendable {
  case completed
  case skipped
  case natural
  case postponed

  public var wasTaken: Bool { self == .completed || self == .natural }
}

public struct BreakRecord: Equatable, Sendable {
  public var kind: BreakKind
  public var result: BreakResult
  public var start: Date
  public var end: Date
  public var planned: TimeInterval

  public init(kind: BreakKind, result: BreakResult, start: Date, end: Date, planned: TimeInterval) {
    self.kind = kind
    self.result = result
    self.start = start
    self.end = max(start, end)
    self.planned = max(0, planned)
  }

  public var rested: TimeInterval { end.timeIntervalSince(start) }
}

public struct WellnessRecord: Equatable, Sendable {
  public var kind: WellnessKind
  public var at: Date
  public var completed: Bool

  public init(kind: WellnessKind, at: Date, completed: Bool) {
    self.kind = kind
    self.at = at
    self.completed = completed
  }
}

public enum TelemetryRecord: Equatable, Sendable {
  case activity(ActivityInterval)
  case breakTaken(BreakRecord)
  case wellness(WellnessRecord)
}
