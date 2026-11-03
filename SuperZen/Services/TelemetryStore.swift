import Foundation
import OSLog
import SuperZenCore
import SwiftData

enum TelemetryStore {
  private static let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "TelemetryStore")

  static var schema: Schema { Schema(versionedSchema: TelemetrySchemaV2.self) }

  static func makeContainer(at url: URL? = nil, fileManager: FileManager = .default) -> ModelContainer {
    let configuration = url.map { ModelConfiguration(schema: schema, url: $0) } ?? ModelConfiguration(schema: schema)
    do {
      return try open(configuration)
    } catch {
      logger.error("Telemetry store failed to open, moving it aside: \(error.localizedDescription, privacy: .public)")
    }
    if quarantine(configuration.url, fileManager: fileManager) {
      do {
        return try open(configuration)
      } catch {
        logger.fault("Fresh telemetry store failed, using memory: \(error.localizedDescription, privacy: .public)")
      }
    }
    do {
      return try makeInMemoryContainer()
    } catch {
      preconditionFailure("Telemetry schema is invalid: \(error)")
    }
  }

  static func makeInMemoryContainer() throws -> ModelContainer {
    try open(ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
  }

  private static func open(_ configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(for: schema, migrationPlan: TelemetryMigrationPlan.self, configurations: [configuration])
  }

  @discardableResult
  static func quarantine(_ url: URL, fileManager: FileManager = .default, now: Date = Date()) -> Bool {
    let suffix = "corrupt-\(Int(now.timeIntervalSince1970))"
    for candidate in [url.path, url.path + "-wal", url.path + "-shm"] where fileManager.fileExists(atPath: candidate) {
      do {
        try fileManager.moveItem(atPath: candidate, toPath: candidate + "." + suffix)
      } catch {
        logger.error("Could not move \(candidate, privacy: .public): \(error.localizedDescription, privacy: .public)")
        return false
      }
    }
    return true
  }
}

@MainActor
enum LegacyTelemetryImporter {
  @discardableResult
  static func run(in context: ModelContext) throws -> Int {
    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    let breaks = try context.fetch(FetchDescriptor<BreakEvent>())
    let wellness = try context.fetch(FetchDescriptor<WellnessEvent>())
    guard !(sessions.isEmpty && breaks.isEmpty && wellness.isEmpty) else { return 0 }

    let records = LegacyTelemetry.convert(
      sessions: sessions.map {
        LegacyTelemetry.Session(start: $0.startTime, activeSeconds: $0.activeSeconds, idleSeconds: $0.idleSeconds)
      },
      breaks: breaks.map {
        LegacyTelemetry.Break(
          endedAt: $0.timestamp, type: $0.type, completed: $0.wasCompleted, duration: $0.durationTaken)
      },
      wellness: wellness.map { LegacyTelemetry.Wellness(at: $0.timestamp, type: $0.type, action: $0.action) })

    records.forEach(context.insertRecord)
    sessions.forEach { context.delete($0) }
    breaks.forEach { context.delete($0) }
    wellness.forEach { context.delete($0) }
    try context.save()
    return records.count
  }
}
