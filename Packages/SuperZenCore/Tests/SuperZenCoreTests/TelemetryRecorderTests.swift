import Foundation
import Testing

@testable import SuperZenCore

private final class IDSequence: @unchecked Sendable {
  private var next = 0
  private let lock = NSLock()

  func make() -> UUID {
    lock.lock()
    defer { lock.unlock() }
    next += 1
    return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", next))!
  }
}

private func recorder(checkpoint: TimeInterval = 300) -> TelemetryRecorder {
  let ids = IDSequence()
  return TelemetryRecorder(checkpoint: checkpoint, makeID: { ids.make() })
}

private func intervals(_ records: [TelemetryRecord]) -> [ActivityInterval] {
  records.compactMap {
    if case .activity(let interval) = $0 { return interval }
    return nil
  }
}

@Suite struct TelemetryRecorderTests {
  @Test func coalescesConsecutiveTicksIntoOneInterval() {
    var subject = recorder()
    _ = subject.record(.focusStarted, at: mondayNoon)
    var emitted: [TelemetryRecord] = []
    for second in 1...60 {
      emitted += subject.record(.activeTime(1), at: mondayNoon.addingTimeInterval(TimeInterval(second)))
    }
    #expect(emitted.isEmpty)
    emitted += subject.record(.focusEnded, at: mondayNoon.addingTimeInterval(60))
    let result = intervals(emitted)
    #expect(result.count == 1)
    #expect(result.first?.start == mondayNoon)
    #expect(result.first?.end == mondayNoon.addingTimeInterval(60))
    #expect(result.first?.kind == .active)
    #expect(subject.sessionID == nil)
  }

  @Test func kindChangeClosesTheOpenInterval() {
    var subject = recorder()
    _ = subject.record(.focusStarted, at: mondayNoon)
    _ = subject.record(.activeTime(10), at: mondayNoon.addingTimeInterval(10))
    let closed = subject.record(.idleTime(5), at: mondayNoon.addingTimeInterval(15))
    #expect(intervals(closed).map(\.kind) == [.active])
    #expect(subject.openInterval?.kind == .idle)
    #expect(subject.openInterval?.duration == 5)
  }

  @Test func gapStartsANewIntervalInTheSameSession() {
    var subject = recorder()
    _ = subject.record(.activeTime(10), at: mondayNoon.addingTimeInterval(10))
    let closed = subject.record(.activeTime(1), at: mondayNoon.addingTimeInterval(100))
    #expect(intervals(closed).first?.end == mondayNoon.addingTimeInterval(10))
    #expect(subject.openInterval?.start == mondayNoon.addingTimeInterval(99))
    #expect(intervals(closed).first?.sessionID == subject.openInterval?.sessionID)
  }

  @Test func checkpointSplitsLongRunsSoCrashesLoseLittle() {
    var subject = recorder(checkpoint: 60)
    var emitted: [TelemetryRecord] = []
    for second in 1...150 {
      emitted += subject.record(.activeTime(1), at: mondayNoon.addingTimeInterval(TimeInterval(second)))
    }
    #expect(intervals(emitted).map(\.duration) == [60, 60])
    #expect(subject.openInterval?.duration == 30)
  }

  @Test func breakEndedClosesSessionAndRecordsOutcome() {
    var subject = recorder()
    _ = subject.record(.focusStarted, at: mondayNoon)
    _ = subject.record(.activeTime(30), at: mondayNoon.addingTimeInterval(30))
    let end = mondayNoon.addingTimeInterval(60)
    let records = subject.record(
      .breakEnded(BreakOutcome(kind: .short, completed: false, rested: 4, planned: 20)), at: end)
    #expect(intervals(records).count == 1)
    #expect(
      records.last
        == .breakTaken(
          BreakRecord(kind: .short, result: .skipped, start: end.addingTimeInterval(-4), end: end, planned: 20)))
    #expect(subject.sessionID == nil)
  }

  @Test func naturalBreakIsRecordedAsTaken() {
    var subject = recorder()
    let records = subject.record(
      .naturalBreak(BreakOutcome(kind: .long, completed: true, rested: 600, planned: 300)), at: mondayNoon)
    guard case .breakTaken(let record) = records.last else {
      Issue.record("expected a break record")
      return
    }
    #expect(record.result == .natural)
    #expect(record.result.wasTaken)
    #expect(record.rested == 600)
  }

  @Test func wellnessDoesNotInterruptTheOpenInterval() {
    var subject = recorder()
    _ = subject.record(.activeTime(5), at: mondayNoon.addingTimeInterval(5))
    let records = subject.record(.wellnessEnded(.blink, completed: true), at: mondayNoon.addingTimeInterval(5))
    #expect(records == [.wellness(WellnessRecord(kind: .blink, at: mondayNoon.addingTimeInterval(5), completed: true))])
    #expect(subject.openInterval?.end == mondayNoon.addingTimeInterval(5))
  }

  @Test func focusStartedIsIdempotentAndNewSessionsGetNewIDs() {
    var subject = recorder()
    _ = subject.record(.focusStarted, at: mondayNoon)
    let first = subject.sessionID
    _ = subject.record(.focusStarted, at: mondayNoon)
    #expect(subject.sessionID == first)
    _ = subject.record(.focusEnded, at: mondayNoon)
    _ = subject.record(.focusStarted, at: mondayNoon)
    #expect(subject.sessionID != first)
  }

  @Test func ignoresNonsenseDeltas() {
    var subject = recorder()
    #expect(subject.record(.activeTime(0), at: mondayNoon).isEmpty)
    #expect(subject.record(.idleTime(-3), at: mondayNoon).isEmpty)
    #expect(subject.record(.activeTime(.infinity), at: mondayNoon).isEmpty)
    #expect(subject.openInterval == nil)
  }

  @Test func engineEventsProduceConsistentRecords() {
    var harness = Harness(settings: quietSettings())
    harness.run(for: 1200)
    harness.run(for: 30)
    harness.runIdle(for: 40)
    harness.run(for: 5)
    var subject = recorder()
    var records: [TelemetryRecord] = []
    var clock = mondayNoon
    var reported: [ActivityKind: TimeInterval] = [:]
    for event in harness.telemetry {
      switch event {
      case .activeTime(let seconds):
        clock = clock.addingTimeInterval(seconds)
        reported[.active, default: 0] += seconds
      case .idleTime(let seconds):
        clock = clock.addingTimeInterval(seconds)
        reported[.idle, default: 0] += seconds
      default:
        break
      }
      records += subject.record(event, at: clock)
    }
    records += subject.flush()
    let snapshot = TelemetrySnapshot(records: records)
    for kind in ActivityKind.allCases {
      let stored = snapshot.activity.filter { $0.kind == kind }.reduce(0) { $0 + $1.duration }
      #expect(stored == reported[kind, default: 0])
    }
    #expect(reported[.idle, default: 0] > 0)
    #expect(snapshot.breaks.map(\.result) == [.completed])
  }
}

@Suite struct LegacyTelemetryTests {
  @Test func convertsSessionsIntoActiveThenIdleIntervals() {
    let id = UUID()
    let records = LegacyTelemetry.convert(
      sessions: [LegacyTelemetry.Session(start: mondayNoon, activeSeconds: 600, idleSeconds: 60)],
      breaks: [],
      wellness: [],
      makeID: { id })
    #expect(
      records == [
        .activity(
          ActivityInterval(sessionID: id, kind: .active, start: mondayNoon, end: mondayNoon.addingTimeInterval(600))),
        .activity(
          ActivityInterval(
            sessionID: id, kind: .idle, start: mondayNoon.addingTimeInterval(600),
            end: mondayNoon.addingTimeInterval(660))),
      ])
  }

  @Test func mapsOldBreakNamesAndOutcomes() {
    let records = LegacyTelemetry.convert(
      sessions: [],
      breaks: [
        LegacyTelemetry.Break(endedAt: mondayNoon, type: "Macro", completed: true, duration: 300),
        LegacyTelemetry.Break(endedAt: mondayNoon, type: "Short", completed: false, duration: 3),
      ],
      wellness: [])
    let breaks = TelemetrySnapshot(records: records).breaks
    #expect(breaks.map(\.kind) == [.long, .short])
    #expect(breaks.map(\.result) == [.completed, .skipped])
    #expect(breaks.first?.start == mondayNoon.addingTimeInterval(-300))
  }

  @Test func dropsUnknownWellnessAndEmptySessions() {
    let records = LegacyTelemetry.convert(
      sessions: [LegacyTelemetry.Session(start: mondayNoon, activeSeconds: 0, idleSeconds: .nan)],
      breaks: [],
      wellness: [
        LegacyTelemetry.Wellness(at: mondayNoon, type: "Posture", action: "completed"),
        LegacyTelemetry.Wellness(at: mondayNoon, type: "stretch", action: "completed"),
      ])
    #expect(records == [.wellness(WellnessRecord(kind: .posture, at: mondayNoon, completed: true))])
  }
}
