import AppKit
import Foundation
import OSLog
import SQLite3
import SuperZenCore
import SwiftData

enum AppRuntime {
  static let isHostingUnitTests = ProcessInfo.processInfo.environment.keys.contains { $0.hasPrefix("XCTest") }
}

enum TelemetryStoreLocation {
  private static let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "TelemetryStore")
  private static let currentTables: Set<String> = ["ZACTIVITYRECORDMODEL", "ZWORKBLOCKAPPUSAGE"]
  private static let originalTables: Set<String> = ["ZFOCUSSESSION", "ZBREAKEVENT", "ZWELLNESSEVENT"]

  static var isAnotherInstanceRunning: Bool {
    guard let identifier = Bundle.main.bundleIdentifier else { return false }
    return NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1
  }

  static func resolve(
    in directory: URL, isAnotherInstanceRunning: Bool, fileManager: FileManager = .default
  ) -> URL {
    let legacy = directory.appendingPathComponent("default.store")
    let folder = directory.appendingPathComponent("SuperZen", isDirectory: true)
    let target = folder.appendingPathComponent("telemetry.store")
    try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    guard !fileManager.fileExists(atPath: target.path), isSuperZenStore(legacy) else { return target }
    if isAnotherInstanceRunning { return legacy }
    return move(legacy, to: target, fileManager: fileManager) ? target : legacy
  }

  static func isSuperZenStore(_ url: URL) -> Bool {
    var database: OpaquePointer?
    defer { sqlite3_close(database) }
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
    sqlite3_busy_timeout(database, 3000)
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }
    let query = "SELECT name FROM sqlite_master WHERE type = 'table'"
    guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else { return false }
    var tables: Set<String> = []
    while sqlite3_step(statement) == SQLITE_ROW {
      if let name = sqlite3_column_text(statement, 0) { tables.insert(String(cString: name)) }
    }
    return !tables.isDisjoint(with: currentTables) || tables.isSuperset(of: originalTables)
  }

  private static func move(_ source: URL, to target: URL, fileManager: FileManager) -> Bool {
    var moved: [(from: String, to: String)] = []
    for suffix in ["-wal", "-shm", ""] where fileManager.fileExists(atPath: source.path + suffix) {
      let destination = target.path + suffix
      do {
        try? fileManager.removeItem(atPath: destination)
        try fileManager.moveItem(atPath: source.path + suffix, toPath: destination)
        moved.append((source.path + suffix, destination))
      } catch {
        logger.error("Could not move telemetry store: \(error.localizedDescription, privacy: .public)")
        moved.forEach { try? fileManager.moveItem(atPath: $0.to, toPath: $0.from) }
        return false
      }
    }
    return true
  }
}

enum TelemetryStore {
  typealias Opener =
    @MainActor (_ configuration: ModelConfiguration, _ usesMigrationPlan: Bool) throws -> ModelContainer

  private static let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "TelemetryStore")

  static var schema: Schema { Schema(versionedSchema: TelemetrySchemaV2.self) }

  static func makeAppContainer() -> ModelContainer {
    if AppRuntime.isHostingUnitTests, let container = try? makeInMemoryContainer() { return container }
    return makeContainer(
      at: TelemetryStoreLocation.resolve(
        in: URL.applicationSupportDirectory,
        isAnotherInstanceRunning: TelemetryStoreLocation.isAnotherInstanceRunning))
  }

  static func makeContainer(
    at url: URL, fileManager: FileManager = .default, opener: Opener = TelemetryStore.open
  ) -> ModelContainer {
    let configuration = ModelConfiguration(schema: schema, url: url)
    if let container = openFirstWorking(configuration, opener: opener) { return container }
    if quarantine(configuration.url, fileManager: fileManager),
      let container = openFirstWorking(configuration, opener: opener)
    {
      return container
    }
    logger.fault("No telemetry store could be opened, using memory")
    let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    if let container = openFirstWorking(memory, opener: opener) { return container }
    preconditionFailure("SwiftData cannot create any container for the telemetry schema")
  }

  static func makeInMemoryContainer() throws -> ModelContainer {
    try open(ModelConfiguration(schema: schema, isStoredInMemoryOnly: true), usesMigrationPlan: true)
  }

  static func open(_ configuration: ModelConfiguration, usesMigrationPlan: Bool) throws -> ModelContainer {
    if usesMigrationPlan {
      return try ModelContainer(
        for: schema, migrationPlan: TelemetryMigrationPlan.self, configurations: [configuration])
    }
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private static func openFirstWorking(_ configuration: ModelConfiguration, opener: Opener) -> ModelContainer? {
    for usesMigrationPlan in [true, false] {
      do {
        return try opener(configuration, usesMigrationPlan)
      } catch {
        logger.error(
          "Telemetry store failed to open (plan: \(usesMigrationPlan, privacy: .public)): \(error.localizedDescription, privacy: .public)"
        )
      }
    }
    return nil
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
