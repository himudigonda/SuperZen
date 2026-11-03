import Foundation
import SQLite3
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

private func temporaryStoreURL() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SuperZenTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory.appendingPathComponent("telemetry.store")
}

@MainActor
private func isolatedDefaults() -> UserDefaults {
  let defaults = UserDefaults(suiteName: "com.himudigonda.SuperZenTests.\(UUID().uuidString)")!
  SettingKey.registerDefaults(in: defaults)
  defaults.set(false, forKey: SettingKey.dataRetentionEnabled)
  return defaults
}

private func localNoon(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
  Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

@MainActor
@Suite(.serialized)
struct TelemetryStoreLocationTests {
  private func temporaryDirectory() throws -> URL {
    try temporaryStoreURL().deletingLastPathComponent()
  }

  private func writeSuperZenStore(at url: URL) throws {
    let container = TelemetryStore.makeContainer(at: url)
    container.mainContext.insertRecord(.wellness(WellnessRecord(kind: .blink, at: Date(), completed: true)))
    try container.mainContext.save()
  }

  private func writeForeignStore(at url: URL) {
    var database: OpaquePointer?
    sqlite3_open(url.path, &database)
    sqlite3_exec(database, "CREATE TABLE ZINVOICE (Z_PK INTEGER PRIMARY KEY)", nil, nil, nil)
    sqlite3_close(database)
  }

  private func target(in directory: URL) -> URL {
    directory.appendingPathComponent("SuperZen/telemetry.store")
  }

  @Test func freshInstallUsesItsOwnFolder() throws {
    let directory = try temporaryDirectory()
    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)
    #expect(url.standardizedFileURL == target(in: directory).standardizedFileURL)
    #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
  }

  @Test func existingHistoryMovesWithItsRecordsIntact() throws {
    let directory = try temporaryDirectory()
    let legacy = directory.appendingPathComponent("default.store")
    try writeSuperZenStore(at: legacy)

    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)

    #expect(url.standardizedFileURL == target(in: directory).standardizedFileURL)
    #expect(!FileManager.default.fileExists(atPath: legacy.path))
    let container = TelemetryStore.makeContainer(at: url)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<WellnessRecordModel>()) == 1)
  }

  @Test func anotherAppsDefaultStoreIsLeftAlone() throws {
    let directory = try temporaryDirectory()
    let foreign = directory.appendingPathComponent("default.store")
    writeForeignStore(at: foreign)
    let before = try Data(contentsOf: foreign)

    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)

    #expect(url.standardizedFileURL == target(in: directory).standardizedFileURL)
    #expect(try Data(contentsOf: foreign) == before)
  }

  @Test func runningInstanceKeepsTheOldStoreInPlace() throws {
    let directory = try temporaryDirectory()
    let legacy = directory.appendingPathComponent("default.store")
    try writeSuperZenStore(at: legacy)

    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: true)

    #expect(url.standardizedFileURL == legacy.standardizedFileURL)
    #expect(FileManager.default.fileExists(atPath: legacy.path))
  }

  @Test func storeInItsOwnFolderWinsOverAnOldCopy() throws {
    let directory = try temporaryDirectory()
    let legacy = directory.appendingPathComponent("default.store")
    try writeSuperZenStore(at: legacy)
    try FileManager.default.createDirectory(
      at: target(in: directory).deletingLastPathComponent(), withIntermediateDirectories: true)
    try writeSuperZenStore(at: target(in: directory))

    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)

    #expect(url.standardizedFileURL == target(in: directory).standardizedFileURL)
    #expect(FileManager.default.fileExists(atPath: legacy.path))
  }

  @Test func unitTestHostNeverOpensTheRealStore() {
    #expect(AppRuntime.isHostingUnitTests)
    let configurations = SuperZenApp.sharedModelContainer.configurations
    #expect(configurations.allSatisfy { $0.isStoredInMemoryOnly })
  }
}

@MainActor
@Suite(.serialized)
struct TelemetryStoreTests {
  @Test func unversionedLegacyStoreMigratesAndImports() throws {
    let url = try temporaryStoreURL()
    let endedAt = localNoon(2026, 10, 20)
    do {
      let legacySchema = Schema([FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self])
      let legacy = try ModelContainer(
        for: legacySchema, configurations: [ModelConfiguration(schema: legacySchema, url: url)])
      let session = FocusSession()
      session.startTime = endedAt.addingTimeInterval(-900)
      session.activeSeconds = 600
      session.idleSeconds = 120
      legacy.mainContext.insert(session)
      let breakEvent = BreakEvent(type: "Macro", wasCompleted: true, durationTaken: 300)
      breakEvent.timestamp = endedAt
      legacy.mainContext.insert(breakEvent)
      legacy.mainContext.insert(WellnessEvent(type: "water", action: "dismissed"))
      legacy.mainContext.insert(
        WorkBlockAppUsage(
          blockID: UUID(), blockStart: endedAt, blockEnd: endedAt, appName: "Xcode",
          bundleIdentifier: "com.apple.dt.Xcode", activeSeconds: 60, activationCount: 1))
      try legacy.mainContext.save()
    }

    let container = TelemetryStore.makeContainer(at: url)
    let context = container.mainContext
    #expect(try LegacyTelemetryImporter.run(in: context) == 4)
    #expect(try LegacyTelemetryImporter.run(in: context) == 0)

    let activity = try context.fetch(FetchDescriptor<ActivityRecordModel>()).compactMap { $0.value }
    #expect(activity.map(\.duration).sorted() == [120, 600])
    let breaks = try context.fetch(FetchDescriptor<BreakRecordModel>()).compactMap { $0.value }
    #expect(
      breaks == [
        BreakRecord(
          kind: .long, result: .completed, start: endedAt.addingTimeInterval(-300), end: endedAt, planned: 300)
      ])
    let wellness = try context.fetch(FetchDescriptor<WellnessRecordModel>()).compactMap { $0.value }
    #expect(wellness.map(\.completed) == [false])
    #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<BreakEvent>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<WorkBlockAppUsage>()) == 1)
  }

  @Test func unreadableStoreIsMovedAsideInsteadOfCrashing() throws {
    let url = try temporaryStoreURL()
    try Data("not a sqlite database".utf8).write(to: url)
    let container = TelemetryStore.makeContainer(at: url)
    container.mainContext.insertRecord(.wellness(WellnessRecord(kind: .blink, at: Date(), completed: true)))
    try container.mainContext.save()
    let files = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(files.contains { $0.contains(".corrupt-") })
    #expect(try container.mainContext.fetchCount(FetchDescriptor<WellnessRecordModel>()) == 1)
  }
}

@MainActor
@Suite(.serialized)
struct TelemetryServiceTests {
  private let start = localNoon(2026, 11, 4, hour: 10)

  private let container: ModelContainer

  init() throws {
    container = try TelemetryStore.makeInMemoryContainer()
  }

  private func makeService() -> (TelemetryService, ModelContext) {
    let service = TelemetryService(saveDelay: .milliseconds(5))
    service.attach(container.mainContext, defaults: isolatedDefaults(), now: start)
    return (service, container.mainContext)
  }

  private func play(_ events: [TelemetryEvent], on service: TelemetryService, from origin: Date) {
    var clock = origin
    for event in events {
      switch event {
      case .activeTime(let seconds), .idleTime(let seconds): clock = clock.addingTimeInterval(seconds)
      default: break
      }
      service.record(event, at: clock)
    }
  }

  @Test func storesCoalescedIntervalsAndOutcomes() throws {
    let (service, context) = makeService()
    let ticks =
      Array(repeating: TelemetryEvent.activeTime(1), count: 120)
      + Array(repeating: TelemetryEvent.idleTime(1), count: 40)
    play(
      [.focusStarted] + ticks
        + [
          .breakEnded(BreakOutcome(kind: .short, completed: false, rested: 0, planned: 20)),
          .focusStarted,
          .wellnessEnded(.posture, completed: true),
          .focusEnded,
          .naturalBreak(BreakOutcome(kind: .long, completed: true, rested: 400, planned: 300)),
        ],
      on: service,
      from: start)

    let activity = try context.fetch(FetchDescriptor<ActivityRecordModel>(sortBy: [SortDescriptor(\.start)]))
      .compactMap { $0.value }
    #expect(activity.map(\.kind) == [.active, .idle])
    #expect(activity.map(\.duration) == [120, 40])
    let results = try context.fetch(FetchDescriptor<BreakRecordModel>()).compactMap { $0.value }.map(\.result)
    #expect(Set(results) == [.skipped, .natural])
    #expect(try context.fetchCount(FetchDescriptor<WellnessRecordModel>()) == 1)
    #expect(!context.hasChanges)
  }

  @Test func eventsBeforeAttachAreKeptAndWritten() throws {
    let service = TelemetryService(saveDelay: .milliseconds(5))
    play([.focusStarted, .activeTime(30), .focusEnded], on: service, from: start)
    let container = try TelemetryStore.makeInMemoryContainer()
    service.attach(container.mainContext, defaults: isolatedDefaults(), now: start)
    let rows = try container.mainContext.fetch(FetchDescriptor<ActivityRecordModel>()).compactMap { $0.value }
    #expect(rows.map(\.duration) == [30])
  }

  @Test func flushOnQuitKeepsTheOpenBlocksAppUsage() throws {
    let tracker = AppUsageTracker()
    let service = TelemetryService(saveDelay: .milliseconds(5), appUsage: tracker)
    service.attach(container.mainContext, defaults: isolatedDefaults(), now: start)
    play([.focusStarted], on: service, from: start)
    tracker.activate(name: "Editor", bundleIdentifier: "test.editor", at: start)
    play([.activeTime(90)], on: service, from: start)
    service.flush(at: start.addingTimeInterval(90))
    let usage = try container.mainContext.fetch(FetchDescriptor<WorkBlockAppUsage>())
    #expect(usage.contains { $0.bundleIdentifier == "test.editor" && $0.activeSeconds > 0 })
  }

  @Test func openIntervalIsVisibleUntilFlushed() throws {
    let (service, context) = makeService()
    play([.focusStarted, .activeTime(1), .activeTime(1)], on: service, from: start)
    #expect(service.openActivity?.duration == 2)
    service.flush()
    #expect(service.openActivity == nil)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 1)
  }

  @Test func retentionPrunesOnceADayWhileRunning() throws {
    let defaults = isolatedDefaults()
    defaults.set(true, forKey: SettingKey.dataRetentionEnabled)
    defaults.set(30, forKey: SettingKey.dataRetentionDays)
    let service = TelemetryService(saveDelay: .milliseconds(5))
    service.attach(container.mainContext, defaults: defaults, now: start)
    let old = start.addingTimeInterval(-40 * 86_400)
    container.mainContext.insertRecord(
      .activity(ActivityInterval(sessionID: UUID(), kind: .active, start: old, end: old.addingTimeInterval(60))))
    try container.mainContext.save()
    play([.focusStarted, .activeTime(60), .focusEnded], on: service, from: start)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 2)
    play([.focusStarted, .activeTime(60), .focusEnded], on: service, from: start.addingTimeInterval(86_400))
    let remaining = try container.mainContext.fetch(FetchDescriptor<ActivityRecordModel>()).map(\.start)
    #expect(remaining.count == 2)
    #expect(remaining.allSatisfy { $0.isAtOrAfter(start) })
  }

  @Test func pruneKeepsRecentRowsAndClearRemovesEverything() throws {
    let (service, context) = makeService()
    let old = start.addingTimeInterval(-40 * 86_400)
    play(
      [.focusStarted, .activeTime(60), .focusEnded, .wellnessEnded(.blink, completed: true)], on: service, from: old)
    play([.focusStarted, .activeTime(60), .focusEnded], on: service, from: start)

    let pruned = service.pruneHistoricalData(retainingDays: 30, now: start)
    #expect(pruned.sessionsDeleted == 1)
    #expect(pruned.breaksDeleted == 0)
    #expect(pruned.wellnessDeleted == 1)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 1)

    let cleared = try service.clearAllTelemetryData()
    #expect(cleared.sessionsDeleted == 1)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 0)
  }
}
