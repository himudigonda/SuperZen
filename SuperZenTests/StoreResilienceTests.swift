import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

private struct OpenRefused: Error {}

@MainActor
@Suite(.serialized)
struct StoreResilienceTests {
  private func scratchDirectory(named name: String = "SuperZenStore-\(UUID().uuidString)") throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func insertBlink(into container: ModelContainer) throws {
    container.mainContext.insertRecord(.wellness(WellnessRecord(kind: .blink, at: Date(), completed: true)))
    try container.mainContext.save()
  }

  private func blinkCount(in container: ModelContainer) throws -> Int {
    try container.mainContext.fetchCount(FetchDescriptor<WellnessRecordModel>())
  }

  private func writeVersion130Store(at url: URL) throws {
    let schema = Schema([FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self])
    let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    let session = FocusSession()
    session.activeSeconds = 900
    container.mainContext.insert(session)
    container.mainContext.insert(BreakEvent(type: "Micro", wasCompleted: true, durationTaken: 20))
    container.mainContext.insert(WellnessEvent(type: "water", action: "completed"))
    try container.mainContext.save()
  }

  @Test func migrationPlanRejectionStillOpensTheFileStore() throws {
    let url = try scratchDirectory().appendingPathComponent("telemetry.store")
    let container = TelemetryStore.makeContainer(at: url) { configuration, usesMigrationPlan in
      guard !usesMigrationPlan else { throw OpenRefused() }
      return try TelemetryStore.open(configuration, usesMigrationPlan: false)
    }
    try insertBlink(into: container)
    #expect(container.configurations.allSatisfy { !$0.isStoredInMemoryOnly })
    #expect(FileManager.default.fileExists(atPath: url.path))
    let reopened = TelemetryStore.makeContainer(at: url)
    #expect(try blinkCount(in: reopened) == 1)
  }

  @Test func everyFileOpenFailingFallsBackToMemoryWithoutTrapping() throws {
    let url = try scratchDirectory().appendingPathComponent("telemetry.store")
    let container = TelemetryStore.makeContainer(at: url) { configuration, usesMigrationPlan in
      guard configuration.isStoredInMemoryOnly, !usesMigrationPlan else { throw OpenRefused() }
      return try TelemetryStore.open(configuration, usesMigrationPlan: false)
    }
    try insertBlink(into: container)
    #expect(container.configurations.allSatisfy { $0.isStoredInMemoryOnly })
    #expect(try blinkCount(in: container) == 1)
  }

  @Test func readOnlyFolderFallsBackToMemory() throws {
    let directory = try scratchDirectory()
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)
    let container = TelemetryStore.makeContainer(at: url)
    try insertBlink(into: container)
    #expect(try blinkCount(in: container) == 1)
  }

  @Test func missingParentFolderFallsBackToMemory() throws {
    let url = try scratchDirectory().appendingPathComponent("no/such/folder/telemetry.store")
    let container = TelemetryStore.makeContainer(at: url)
    try insertBlink(into: container)
    #expect(try blinkCount(in: container) == 1)
  }

  @Test func foldersWithSpacesAndUnicodePersist() throws {
    let directory = try scratchDirectory(named: "Zen Ünïcode 日本語 \(UUID().uuidString)")
    let url = TelemetryStoreLocation.resolve(in: directory, isAnotherInstanceRunning: false)
    do {
      let container = TelemetryStore.makeContainer(at: url)
      try insertBlink(into: container)
    }
    let reopened = TelemetryStore.makeContainer(at: url)
    #expect(try blinkCount(in: reopened) == 1)
    #expect(reopened.configurations.allSatisfy { !$0.isStoredInMemoryOnly })
  }

  @Test func truncatedStoreIsQuarantinedAndReplaced() throws {
    let url = try scratchDirectory().appendingPathComponent("telemetry.store")
    do {
      let container = TelemetryStore.makeContainer(at: url)
      try insertBlink(into: container)
    }
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: 100)
    try handle.close()
    try? FileManager.default.removeItem(atPath: url.path + "-wal")
    try? FileManager.default.removeItem(atPath: url.path + "-shm")

    let container = TelemetryStore.makeContainer(at: url)
    try insertBlink(into: container)
    #expect(try blinkCount(in: container) == 1)
    let files = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(files.contains { $0.contains(".corrupt-") })
  }

  @Test func emptyFileIsTreatedAsAFreshStore() throws {
    let url = try scratchDirectory().appendingPathComponent("telemetry.store")
    try Data().write(to: url)
    let container = TelemetryStore.makeContainer(at: url)
    try insertBlink(into: container)
    #expect(try blinkCount(in: container) == 1)
  }

  @Test func version130StoreAtDefaultStoreSurvivesTheWholeUpgradePath() throws {
    let applicationSupport = try scratchDirectory()
    try writeVersion130Store(at: applicationSupport.appendingPathComponent("default.store"))

    let url = TelemetryStoreLocation.resolve(in: applicationSupport, isAnotherInstanceRunning: false)
    let container = TelemetryStore.makeContainer(at: url)

    #expect(url.lastPathComponent == "telemetry.store")
    #expect(container.configurations.allSatisfy { !$0.isStoredInMemoryOnly })
    #expect(try LegacyTelemetryImporter.run(in: container.mainContext) == 3)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 1)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<BreakRecordModel>()) == 1)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<WellnessRecordModel>()) == 1)
  }

  @Test func version130StoreOpensWithoutAMigrationPlanToo() throws {
    let url = try scratchDirectory().appendingPathComponent("default.store")
    try writeVersion130Store(at: url)
    let container = try TelemetryStore.open(
      ModelConfiguration(schema: TelemetryStore.schema, url: url), usesMigrationPlan: false)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<FocusSession>()) == 1)
  }
}
