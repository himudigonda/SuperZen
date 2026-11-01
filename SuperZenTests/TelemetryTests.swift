import Foundation
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
struct TelemetryStoreTests {
  @Test func unversionedLegacyStoreMigratesAndImports() throws {
    let url = try temporaryStoreURL()
    let endedAt = localNoon(2026, 10, 20)
    do {
      let legacySchema = Schema([FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self])
      let legacy = try ModelContainer(for: legacySchema, configurations: [ModelConfiguration(schema: legacySchema, url: url)])
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
    #expect(breaks == [BreakRecord(kind: .long, result: .completed, start: endedAt.addingTimeInterval(-300), end: endedAt, planned: 300)])
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
    let ticks = Array(repeating: TelemetryEvent.activeTime(1), count: 120)
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

  @Test func openIntervalIsVisibleUntilFlushed() throws {
    let (service, context) = makeService()
    play([.focusStarted, .activeTime(1), .activeTime(1)], on: service, from: start)
    #expect(service.openActivity?.duration == 2)
    service.flush()
    #expect(service.openActivity == nil)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 1)
  }

  @Test func pruneKeepsRecentRowsAndClearRemovesEverything() throws {
    let (service, context) = makeService()
    let old = start.addingTimeInterval(-40 * 86_400)
    play([.focusStarted, .activeTime(60), .focusEnded, .wellnessEnded(.blink, completed: true)], on: service, from: old)
    play([.focusStarted, .activeTime(60), .focusEnded], on: service, from: start)

    let pruned = service.pruneHistoricalData(retainingDays: 30, now: start)
    #expect(pruned.sessionsDeleted == 1)
    #expect(pruned.breaksDeleted == 0)
    #expect(pruned.wellnessDeleted == 1)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 1)

    let cleared = service.clearAllTelemetryData()
    #expect(cleared.sessionsDeleted == 1)
    #expect(try context.fetchCount(FetchDescriptor<ActivityRecordModel>()) == 0)
  }
}

@MainActor
@Suite(.serialized)
struct DashboardViewModelTests {
  private let now = localNoon(2026, 11, 4)
  private let defaults: UserDefaults
  private let container: ModelContainer

  init() throws {
    defaults = isolatedDefaults()
    container = try TelemetryStore.makeInMemoryContainer()
  }

  private func makeContext(_ records: [TelemetryRecord]) throws -> ModelContext {
    let context = container.mainContext
    records.forEach(context.insertRecord)
    try context.save()
    return context
  }

  private func makeViewModel() -> DashboardViewModel {
    defaults.set(60, forKey: SettingKey.dailyFocusGoalMinutes)
    return DashboardViewModel(calendar: .current, defaults: defaults, liveActivity: { nil })
  }

  private func focus(daysAgo: Int, minutes: Double, session: UUID = UUID()) -> TelemetryRecord {
    let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: localNoon(2026, 11, 4, hour: 9))!
    return .activity(ActivityInterval(sessionID: session, kind: .active, start: day, end: day.addingTimeInterval(minutes * 60)))
  }

  @Test func emptyStoreIsNeutralAndZeroSafe() throws {
    let viewModel = makeViewModel()
    viewModel.load(context: try makeContext([]), now: now)
    #expect(viewModel.focusedMinutes == 0)
    #expect(viewModel.focusQualityScore == 50)
    #expect(viewModel.trendAvailable == false)
    #expect(viewModel.chartPoints.count == 24)
    #expect(viewModel.consistencyStreakDays == 0)
  }

  @Test func todayReflectsStoredRecords() throws {
    let breakEnd = localNoon(2026, 11, 4, hour: 11)
    let records = [
      focus(daysAgo: 0, minutes: 90),
      focus(daysAgo: 1, minutes: 30),
      .breakTaken(BreakRecord(kind: .short, result: .completed, start: breakEnd.addingTimeInterval(-20), end: breakEnd, planned: 20)),
      .breakTaken(BreakRecord(kind: .short, result: .skipped, start: breakEnd, end: breakEnd, planned: 20)),
    ]
    let viewModel = makeViewModel()
    viewModel.load(context: try makeContext(records), now: now)
    #expect(viewModel.focusedMinutes == 90)
    #expect(viewModel.sessionsCount == 1)
    #expect(viewModel.breakCompletionRate == 50)
    #expect(viewModel.skippedBreakCount == 1)
    #expect(viewModel.trendAvailable)
    #expect(viewModel.trendDeltaPercent == 200)
    #expect(viewModel.consistencyStreakDays == 1)
    #expect(viewModel.forecastText == "Focus goal already achieved today.")
  }

  @Test func rangeSwitchRefetchesAndRebuckets() throws {
    let viewModel = makeViewModel()
    viewModel.load(context: try makeContext([focus(daysAgo: 3, minutes: 45), focus(daysAgo: 20, minutes: 15)]), now: now)
    #expect(viewModel.focusedMinutes == 0)
    viewModel.selectedRange = .week
    viewModel.refreshForSelectedRange(now: now)
    #expect(viewModel.chartPoints.count == 7)
    #expect(viewModel.focusedMinutes == 45)
    viewModel.selectedRange = .month
    viewModel.refreshForSelectedRange(now: now)
    #expect(viewModel.chartPoints.count == 30)
    #expect(viewModel.focusedMinutes == 60)
    #expect(viewModel.activeDaysCount == 2)
  }

  @Test func streakLooksBeyondTheInitialWindow() throws {
    let records = (0..<50).map { focus(daysAgo: $0, minutes: 61) }
    let viewModel = makeViewModel()
    viewModel.load(context: try makeContext(records), now: now)
    #expect(viewModel.consistencyStreakDays == 50)
  }

  @Test func liveIntervalCountsBeforeItIsSaved() throws {
    let open = ActivityInterval(
      sessionID: UUID(), kind: .active, start: now.addingTimeInterval(-600), end: now)
    defaults.set(60, forKey: SettingKey.dailyFocusGoalMinutes)
    let viewModel = DashboardViewModel(calendar: .current, defaults: defaults, liveActivity: { open })
    viewModel.load(context: try makeContext([]), now: now)
    #expect(viewModel.focusedMinutes == 10)
  }

  @Test func disabledForecastSaysSo() throws {
    defaults.set(false, forKey: SettingKey.insightsForecastEnabled)
    let viewModel = makeViewModel()
    viewModel.load(context: try makeContext([]), now: now)
    #expect(viewModel.forecastText == "Forecast disabled in settings.")
  }

  @Test func forecastCopyCoversEveryCase() {
    let eta = localNoon(2026, 11, 4, hour: 15)
    let cases: [Forecast] = [
      .goalMet, .beforeWorkday(needed: 600), .gatheringPace(needed: 600), .onTrack(eta: eta),
      .shortfall(projected: 1200, goal: 3600), .workdayOver(shortBy: 60), .pace(delta: 0.1), .pace(delta: -0.25),
    ]
    let texts = cases.map(DashboardViewModel.describe)
    #expect(Set(texts).count == cases.count)
    #expect(texts.last == "You're behind pace by 25%.")
    #expect(texts[4].contains("20m of your 60m"))
  }
}
