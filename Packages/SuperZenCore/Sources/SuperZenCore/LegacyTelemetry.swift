import Foundation

public enum LegacyTelemetry {
  public struct Session: Equatable, Sendable {
    public var start: Date
    public var activeSeconds: Double
    public var idleSeconds: Double

    public init(start: Date, activeSeconds: Double, idleSeconds: Double) {
      self.start = start
      self.activeSeconds = activeSeconds
      self.idleSeconds = idleSeconds
    }
  }

  public struct Break: Equatable, Sendable {
    public var endedAt: Date
    public var type: String
    public var completed: Bool
    public var duration: TimeInterval

    public init(endedAt: Date, type: String, completed: Bool, duration: TimeInterval) {
      self.endedAt = endedAt
      self.type = type
      self.completed = completed
      self.duration = duration
    }
  }

  public struct Wellness: Equatable, Sendable {
    public var at: Date
    public var type: String
    public var action: String

    public init(at: Date, type: String, action: String) {
      self.at = at
      self.type = type
      self.action = action
    }
  }

  public static func convert(
    sessions: [Session],
    breaks: [Break],
    wellness: [Wellness],
    makeID: () -> UUID = { UUID() }
  ) -> [TelemetryRecord] {
    sessions.flatMap { convert($0, id: makeID()) }
      + breaks.map(convert)
      + wellness.compactMap(convert)
  }

  static func convert(_ session: Session, id: UUID) -> [TelemetryRecord] {
    let active = sanitized(session.activeSeconds)
    let idle = sanitized(session.idleSeconds)
    let activeEnd = session.start.addingTimeInterval(active)
    var records: [TelemetryRecord] = []
    if active > 0 {
      records.append(.activity(ActivityInterval(sessionID: id, kind: .active, start: session.start, end: activeEnd)))
    }
    if idle > 0 {
      records.append(
        .activity(
          ActivityInterval(sessionID: id, kind: .idle, start: activeEnd, end: activeEnd.addingTimeInterval(idle))))
    }
    return records
  }

  static func convert(_ legacy: Break) -> TelemetryRecord {
    let rested = sanitized(legacy.duration)
    let kind: BreakKind = ["long", "macro"].contains(legacy.type.lowercased()) ? .long : .short
    return .breakTaken(
      BreakRecord(
        kind: kind,
        result: legacy.completed ? .completed : .skipped,
        start: legacy.endedAt.addingTimeInterval(-rested),
        end: legacy.endedAt,
        planned: rested))
  }

  static func convert(_ legacy: Wellness) -> TelemetryRecord? {
    guard let kind = WellnessKind(rawValue: legacy.type.lowercased()) else { return nil }
    return .wellness(WellnessRecord(kind: kind, at: legacy.at, completed: legacy.action == "completed"))
  }

  private static func sanitized(_ value: Double) -> Double {
    value.isFinite ? min(max(0, value), ActivityInterval.maximumSpan) : 0
  }
}
