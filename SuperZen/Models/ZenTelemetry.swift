import Foundation
import SuperZenCore
import SwiftData

typealias FocusSession = TelemetrySchemaV1.FocusSession
typealias BreakEvent = TelemetrySchemaV1.BreakEvent
typealias WellnessEvent = TelemetrySchemaV1.WellnessEvent
typealias WorkBlockAppUsage = TelemetrySchemaV1.WorkBlockAppUsage
typealias ActivityRecordModel = TelemetrySchemaV2.ActivityRecordModel
typealias BreakRecordModel = TelemetrySchemaV2.BreakRecordModel
typealias WellnessRecordModel = TelemetrySchemaV2.WellnessRecordModel

nonisolated enum TelemetrySchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self]
  }

  @Model
  final class FocusSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var activeSeconds: Double = 0
    var idleSeconds: Double = 0
    var interruptions: Int = 0
    var skips: Int = 0

    init() {}
  }

  @Model
  final class BreakEvent {
    var id: UUID
    var timestamp: Date
    var type: String
    var wasCompleted: Bool
    var durationTaken: TimeInterval

    init(type: String, wasCompleted: Bool, durationTaken: TimeInterval) {
      id = UUID()
      timestamp = Date()
      self.type = type
      self.wasCompleted = wasCompleted
      self.durationTaken = durationTaken
    }
  }

  @Model
  final class WellnessEvent {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var type: String
    var action: String

    init(type: String, action: String) {
      self.type = type
      self.action = action
    }
  }

  @Model
  final class WorkBlockAppUsage {
    var id: UUID = UUID()
    var blockID: UUID
    var blockStart: Date
    var blockEnd: Date
    var appName: String
    var bundleIdentifier: String
    var activeSeconds: Double
    var activationCount: Int

    init(
      blockID: UUID,
      blockStart: Date,
      blockEnd: Date,
      appName: String,
      bundleIdentifier: String,
      activeSeconds: Double,
      activationCount: Int
    ) {
      self.blockID = blockID
      self.blockStart = blockStart
      self.blockEnd = blockEnd
      self.appName = appName
      self.bundleIdentifier = bundleIdentifier
      self.activeSeconds = activeSeconds
      self.activationCount = activationCount
    }
  }
}

nonisolated enum TelemetrySchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      TelemetrySchemaV1.FocusSession.self,
      TelemetrySchemaV1.BreakEvent.self,
      TelemetrySchemaV1.WellnessEvent.self,
      TelemetrySchemaV1.WorkBlockAppUsage.self,
      ActivityRecordModel.self,
      BreakRecordModel.self,
      WellnessRecordModel.self,
    ]
  }

  @Model
  final class ActivityRecordModel {
    var sessionID: UUID = UUID()
    var kindRaw: String = ActivityKind.active.rawValue
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast

    init(_ interval: ActivityInterval) {
      sessionID = interval.sessionID
      kindRaw = interval.kind.rawValue
      start = interval.start
      end = interval.end
    }

    var value: ActivityInterval? {
      ActivityKind(rawValue: kindRaw).map { ActivityInterval(sessionID: sessionID, kind: $0, start: start, end: end) }
    }
  }

  @Model
  final class BreakRecordModel {
    var kindRaw: String = BreakKind.short.rawValue
    var resultRaw: String = BreakResult.completed.rawValue
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var planned: Double = 0

    init(_ record: BreakRecord) {
      kindRaw = record.kind.rawValue
      resultRaw = record.result.rawValue
      start = record.start
      end = record.end
      planned = record.planned
    }

    var value: BreakRecord? {
      guard let kind = BreakKind(rawValue: kindRaw), let result = BreakResult(rawValue: resultRaw) else { return nil }
      return BreakRecord(kind: kind, result: result, start: start, end: end, planned: planned)
    }
  }

  @Model
  final class WellnessRecordModel {
    var kindRaw: String = WellnessKind.posture.rawValue
    var at: Date = Date.distantPast
    var completed: Bool = false

    init(_ record: WellnessRecord) {
      kindRaw = record.kind.rawValue
      at = record.at
      completed = record.completed
    }

    var value: WellnessRecord? {
      WellnessKind(rawValue: kindRaw).map { WellnessRecord(kind: $0, at: at, completed: completed) }
    }
  }
}

nonisolated enum TelemetryMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [TelemetrySchemaV1.self, TelemetrySchemaV2.self]
  }

  static var stages: [MigrationStage] {
    [.lightweight(fromVersion: TelemetrySchemaV1.self, toVersion: TelemetrySchemaV2.self)]
  }
}

extension ModelContext {
  func insertRecord(_ record: TelemetryRecord) {
    switch record {
    case .activity(let interval): insert(ActivityRecordModel(interval))
    case .breakTaken(let record): insert(BreakRecordModel(record))
    case .wellness(let record): insert(WellnessRecordModel(record))
    }
  }
}
