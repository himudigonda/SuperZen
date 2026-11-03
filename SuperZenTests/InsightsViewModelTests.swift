import Combine
import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

private func november(_ day: Int, hour: Int, minute: Int = 0) -> Date {
  Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

@MainActor
private func insightsDefaults() -> UserDefaults {
  let defaults = UserDefaults(suiteName: "com.himudigonda.SuperZenTests.insights.\(UUID().uuidString)")!
  SettingKey.registerDefaults(in: defaults)
  defaults.set(false, forKey: SettingKey.dataRetentionEnabled)
  defaults.set(60, forKey: SettingKey.dailyFocusGoalMinutes)
  defaults.set(4, forKey: SettingKey.dailyBreakGoalCount)
  return defaults
}

private struct ClearFailure: Error {}

@MainActor
@Suite(.serialized)
struct InsightsViewModelTests {
  private let now = november(4, hour: 12)
  private let defaults: UserDefaults
  private let container: ModelContainer
  private let center = NotificationCenter()

  init() throws {
    defaults = insightsDefaults()
    container = try TelemetryStore.makeInMemoryContainer()
  }

  private var context: ModelContext { container.mainContext }

  private func store(_ records: [TelemetryRecord]) throws {
    records.forEach(context.insertRecord)
    try context.save()
  }

  private func makeViewModel(
    live: ActivityInterval? = nil,
    clear: (@MainActor () throws -> Int)? = nil
  ) -> InsightsViewModel {
    let fixed = now
    return InsightsViewModel(
      calendar: .current,
      defaults: defaults,
      notificationCenter: center,
      clock: { fixed },
      liveActivity: { live },
      clearData: clear ?? { 0 })
  }

  private func focus(daysAgo: Int, hour: Int = 9, minutes: Double) -> TelemetryRecord {
    let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: november(4, hour: hour))!
    return .activity(
      ActivityInterval(sessionID: UUID(), kind: .active, start: start, end: start.addingTimeInterval(minutes * 60)))
  }

  private func breakRecord(_ result: BreakResult, endingAt end: Date) -> TelemetryRecord {
    .breakTaken(BreakRecord(kind: .short, result: result, start: end.addingTimeInterval(-20), end: end, planned: 20))
  }

  private func kpi(_ kind: InsightsViewModel.KPIKind, in viewModel: InsightsViewModel) -> InsightsViewModel.KPI? {
    viewModel.kpis.first { $0.kind == kind }
  }

  private var todaysRecords: [TelemetryRecord] {
    [
      focus(daysAgo: 0, minutes: 90),
      focus(daysAgo: 1, minutes: 30),
      breakRecord(.completed, endingAt: november(4, hour: 11)),
      breakRecord(.skipped, endingAt: november(4, hour: 11, minute: 30)),
    ]
  }

  @Test func skipCardStaysHiddenBelowTheSampleMinimum() throws {
    try store(
      (0..<(SkipPattern.minimumBreaksPerHour - 1)).map {
        breakRecord(.skipped, endingAt: november(3 - $0, hour: 15, minute: 10))
      })
    let viewModel = makeViewModel()
    viewModel.load(context: context)

    #expect(viewModel.skipAdvice == .insufficientData)
    #expect(viewModel.skipPatternHour == nil)
  }

  @Test func skipCardAppearsOnceTheSampleMinimumIsMet() throws {
    try store(
      (0..<SkipPattern.minimumBreaksPerHour).map {
        breakRecord(.skipped, endingAt: november(3 - $0, hour: 15, minute: 10))
      })
    let viewModel = makeViewModel()
    viewModel.load(context: context)

    #expect(viewModel.skipPatternHour == 15)
  }

  @Test func emptyHistoryShowsEmptyStatesAndNeutralKPIs() {
    let viewModel = makeViewModel()
    viewModel.load(context: context)

    #expect(viewModel.isLoaded)
    #expect(!viewModel.loadFailed)
    #expect(!viewModel.hasRangeData)
    #expect(!viewModel.hasStoredData)
    #expect(!viewModel.hasHeatmapData)
    #expect(viewModel.kpis.map(\.kind) == InsightsViewModel.KPIKind.allCases)
    #expect(kpi(.focus, in: viewModel)?.value == "0m")
    #expect(kpi(.focus, in: viewModel)?.caption == "of 1h goal")
    #expect(kpi(.quality, in: viewModel)?.value == InsightsFormat.noValue)
    #expect(kpi(.quality, in: viewModel)?.progress == nil)
    #expect(viewModel.trend.count == 24)
    #expect(viewModel.timelineBlocks.isEmpty)
    #expect(viewModel.heatmap.count == 7 * 24)
    #expect(viewModel.forecastText == nil)
    #expect(viewModel.goalLineMinutes == nil)
    #expect(viewModel.lastUpdated == now)
  }

  @Test func todayCombinesKPIsTimelineAndHeatmap() throws {
    try store(todaysRecords)
    let viewModel = makeViewModel()
    viewModel.load(context: context)

    #expect(viewModel.hasRangeData)
    #expect(viewModel.hasStoredData)
    #expect(kpi(.focus, in: viewModel)?.value == "1h 30m")
    #expect(kpi(.focus, in: viewModel)?.progress == 1)
    #expect(kpi(.breaks, in: viewModel)?.value == "1")
    #expect(kpi(.breaks, in: viewModel)?.caption == "Goal 4, 1 skipped")
    #expect(kpi(.breaks, in: viewModel)?.progress == 0.25)
    #expect(kpi(.streak, in: viewModel)?.value == "1 day")
    #expect(viewModel.details.first { $0.id == "trend" }?.value == "+200%")
    #expect(viewModel.forecastText == InsightsViewModel.describe(.goalMet))

    #expect(viewModel.timelineBlocks.map(\.lane) == [.focus, .rest])
    #expect(viewModel.timelineBlocks.first?.start == november(4, hour: 9))
    #expect(viewModel.timelineTotals[.focus] == 5400)
    #expect(viewModel.timelineSummary.contains("1h 30m"))

    #expect(viewModel.hasHeatmapData)
    #expect(viewModel.heatmapPeakMinutes == 60)
    #expect(viewModel.heatmap.filter { $0.minutes > 0 }.map(\.minutes).reduce(0, +) == 120)
    #expect(viewModel.heatmapSummary.contains("with 1h of focus"))
  }

  @Test func rangeSwitchRebucketsAndScalesGoals() throws {
    try store([focus(daysAgo: 3, minutes: 45), focus(daysAgo: 20, minutes: 15)])
    let viewModel = makeViewModel()
    viewModel.load(context: context)
    #expect(kpi(.focus, in: viewModel)?.value == "0m")

    viewModel.select(.week)
    #expect(viewModel.selectedRange == .week)
    #expect(viewModel.trend.count == 7)
    #expect(kpi(.focus, in: viewModel)?.value == "45m")
    #expect(kpi(.focus, in: viewModel)?.caption == "of 7h goal")
    #expect(viewModel.goalLineMinutes == 60)

    viewModel.select(.month)
    #expect(viewModel.trend.count == 30)
    #expect(kpi(.focus, in: viewModel)?.value == "1h")
    #expect(kpi(.breaks, in: viewModel)?.caption == "Goal 120, 0 skipped")
  }

  @Test func goalLineFollowsTheSetting() throws {
    defaults.set(false, forKey: SettingKey.insightsShowGoalLine)
    let viewModel = makeViewModel()
    viewModel.load(context: context)
    viewModel.select(.week)
    #expect(viewModel.goalLineMinutes == nil)
  }

  @Test func disabledForecastIsHidden() throws {
    defaults.set(false, forKey: SettingKey.insightsForecastEnabled)
    try store(todaysRecords)
    let viewModel = makeViewModel()
    viewModel.load(context: context)
    #expect(viewModel.forecastText == nil)
  }

  @Test func liveIntervalCountsBeforeItIsSaved() {
    let open = ActivityInterval(sessionID: UUID(), kind: .active, start: now.addingTimeInterval(-600), end: now)
    let viewModel = makeViewModel(live: open)
    viewModel.load(context: context)
    #expect(kpi(.focus, in: viewModel)?.value == "10m")
    #expect(viewModel.hasStoredData)
    #expect(viewModel.timelineBlocks.map(\.lane) == [.focus])
  }

  @Test func streakLooksBeyondTheInitialWindow() throws {
    try store((0..<50).map { focus(daysAgo: $0, minutes: 61) })
    let viewModel = makeViewModel()
    viewModel.load(context: context)
    #expect(kpi(.streak, in: viewModel)?.value == "50 days")
  }

  @Test func telemetryChangeRefreshesLiveOnlyAfterLoad() throws {
    let viewModel = makeViewModel()
    center.post(name: .superZenTelemetryDidChange, object: nil)
    #expect(!viewModel.isLoaded)

    viewModel.load(context: context)
    #expect(kpi(.focus, in: viewModel)?.value == "0m")
    try store(todaysRecords)
    center.post(name: .superZenTelemetryDidChange, object: nil)
    #expect(kpi(.focus, in: viewModel)?.value == "1h 30m")
  }

  @Test func clearingHistoryReportsAndRefreshes() throws {
    let service = TelemetryService(saveDelay: .milliseconds(5), notificationCenter: center)
    service.attach(context, defaults: defaults, now: now)
    try store(todaysRecords)
    let viewModel = makeViewModel(clear: { try service.clearAllTelemetryData().totalDeleted })
    viewModel.load(context: context)
    #expect(viewModel.hasStoredData)

    viewModel.clearAllData()
    #expect(viewModel.clearOutcome == .cleared(records: 4))
    #expect(!viewModel.hasStoredData)
    #expect(!viewModel.hasRangeData)
    #expect(kpi(.focus, in: viewModel)?.value == "0m")

    viewModel.dismissClearOutcome()
    #expect(viewModel.clearOutcome == nil)
  }

  @Test func failedClearKeepsHistoryVisible() throws {
    try store(todaysRecords)
    let viewModel = makeViewModel(clear: { throw ClearFailure() })
    viewModel.load(context: context)
    viewModel.clearAllData()
    #expect(viewModel.clearOutcome == .failed)
    #expect(viewModel.hasStoredData)
    #expect(kpi(.focus, in: viewModel)?.value == "1h 30m")
  }

  @Test func forecastCopyCoversEveryCase() {
    let cases: [Forecast] = [
      .goalMet, .beforeWorkday(needed: 600), .gatheringPace(needed: 600), .onTrack(eta: november(4, hour: 15)),
      .shortfall(projected: 1200, goal: 3600), .workdayOver(shortBy: 60), .pace(delta: 0.1), .pace(delta: -0.25),
    ]
    let texts = cases.map(InsightsViewModel.describe)
    #expect(Set(texts).count == cases.count)
    #expect(texts.last == "Behind pace by 25%.")
    #expect(texts[4].contains("20m of your 1h goal"))
  }
}

@MainActor
@Suite struct InsightsFormatTests {
  @Test func durationsAreCompactAndSafe() {
    #expect(InsightsFormat.duration(0) == "0m")
    #expect(InsightsFormat.duration(59) == "0m")
    #expect(InsightsFormat.duration(59 * 60) == "59m")
    #expect(InsightsFormat.duration(3600) == "1h")
    #expect(InsightsFormat.duration(5400) == "1h 30m")
    #expect(InsightsFormat.duration(-30) == "0m")
    #expect(InsightsFormat.duration(.infinity) == "0m")
    #expect(InsightsFormat.duration(.nan) == "0m")
  }

  @Test func trendShowsSignAndHandlesMissingBaseline() {
    #expect(InsightsFormat.trend(nil) == "No baseline")
    #expect(InsightsFormat.trend(0.5) == "+50%")
    #expect(InsightsFormat.trend(-0.25) == "-25%")
    #expect(InsightsFormat.trend(0) == "0%")
  }
}

@MainActor
@Suite(.serialized)
struct TelemetryChangeNotificationTests {
  @Test func savesAndClearsAnnounceChanges() throws {
    let container = try TelemetryStore.makeInMemoryContainer()
    let center = NotificationCenter()
    var posts = 0
    let subscription = center.publisher(for: .superZenTelemetryDidChange).sink { _ in posts += 1 }
    defer { subscription.cancel() }

    let service = TelemetryService(saveDelay: .milliseconds(5), notificationCenter: center)
    service.attach(container.mainContext, defaults: insightsDefaults(), now: november(4, hour: 9))
    let afterAttach = posts
    service.record(.focusStarted, at: november(4, hour: 9))
    service.record(.activeTime(60), at: november(4, hour: 9, minute: 1))
    service.record(.focusEnded, at: november(4, hour: 9, minute: 1))
    #expect(posts > afterAttach)

    let beforeClear = posts
    #expect(try service.clearAllTelemetryData().sessionsDeleted == 1)
    #expect(posts > beforeClear)
  }
}
