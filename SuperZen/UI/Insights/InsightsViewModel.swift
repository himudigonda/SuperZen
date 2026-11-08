import Combine
import Foundation
import OSLog
import SuperZenCore
import SwiftData

@MainActor
final class InsightsViewModel: ObservableObject {
  static let initialStreakLookbackDays = 35
  static let maximumStreakLookbackDays = 3650
  static let heatmapDays = 7

  @Published private(set) var selectedRange: Range = .today
  @Published private(set) var insights: Insights?
  @Published private(set) var isLoaded = false
  @Published private(set) var loadFailed = false
  @Published private(set) var lastUpdated: Date?
  @Published private(set) var kpis: [KPI] = []
  @Published private(set) var details: [DetailStat] = []
  @Published private(set) var trend: [TrendPoint] = []
  @Published private(set) var goalLineMinutes: Double?
  @Published private(set) var timelineBlocks: [TimelineBlock] = []
  @Published private(set) var timelineDomain: DateInterval?
  @Published private(set) var heatmap: [HeatPoint] = []
  @Published private(set) var heatmapDays: [Date] = []
  @Published private(set) var heatmapPeakMinutes: Double = 0
  @Published private(set) var forecastText: String?
  @Published private(set) var wellnessStats: [WellnessTypeStat] = []
  @Published private(set) var workBlockAppSummaries: [WorkBlockAppSummary] = []
  @Published private(set) var topAppsInRange: [TopAppSummary] = []
  @Published private(set) var hasStoredData = false
  @Published var skipAdvice: SkipAdvice = .insufficientData
  @Published private(set) var clearOutcome: ClearOutcome?
  @Published var selectedWorkBlockID: UUID?

  private let calculator: InsightsCalculator
  private let defaults: UserDefaults
  private let clock: @MainActor () -> Date
  private let liveActivity: @MainActor () -> ActivityInterval?
  private let clearData: @MainActor () throws -> Int
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Insights")
  private(set) var context: ModelContext?
  private var subscriptions = Set<AnyCancellable>()

  init(
    calendar: Calendar = .current,
    defaults: UserDefaults = .standard,
    notificationCenter: NotificationCenter = .default,
    clock: @escaping @MainActor () -> Date = { Date() },
    liveActivity: @escaping @MainActor () -> ActivityInterval? = { TelemetryService.shared.openActivity },
    clearData: @escaping @MainActor () throws -> Int = {
      try TelemetryService.shared.clearAllTelemetryData().totalDeleted
    }
  ) {
    calculator = InsightsCalculator(calendar: calendar)
    self.defaults = defaults
    self.clock = clock
    self.liveActivity = liveActivity
    self.clearData = clearData
    notificationCenter.publisher(for: .superZenTelemetryDidChange)
      .sink { [weak self] _ in
        MainActor.assumeIsolated { self?.refresh() }
      }
      .store(in: &subscriptions)
  }

  var hasRangeData: Bool { insights?.hasData ?? false }
  var hasHeatmapData: Bool { heatmapPeakMinutes > 0 }

  var selectedWorkBlockSummary: WorkBlockAppSummary? {
    guard let selectedWorkBlockID else { return workBlockAppSummaries.last }
    return workBlockAppSummaries.first { $0.id == selectedWorkBlockID }
  }

  var timelineTotals: [TimelineLane: TimeInterval] {
    timelineBlocks.reduce(into: [:]) { $0[$1.lane, default: 0] += $1.duration }
  }

  var timelineSummary: String {
    let totals = timelineTotals
    let parts = TimelineLane.allCases.map { lane in
      "\(lane.title) \(InsightsFormat.duration(totals[lane] ?? 0))"
    }
    return parts.joined(separator: ", ")
  }

  var heatmapSummary: String {
    guard let peak = heatmap.max(by: { $0.minutes < $1.minutes }), peak.minutes > 0 else {
      return String(
        localized: "No focus recorded in the last 7 days", comment: "Insights heatmap accessibility summary")
    }
    let activeHours = heatmap.filter { $0.minutes > 0 }.count
    let when = "\(InsightsFormat.weekday(peak.day)) \(InsightsFormat.hour(peak.hour, on: peak.day))"
    return String(
      localized:
        "Busiest hour \(when) with \(InsightsFormat.duration(peak.minutes * 60)) of focus. Focus in \(activeHours) of \(heatmap.count) hours.",
      comment: "Insights heatmap accessibility summary")
  }

  func load(context: ModelContext) {
    if context === TelemetryService.shared.context { TelemetryService.shared.saveNow() }
    self.context = context
    refresh()
  }

  func select(_ range: Range) {
    guard range != selectedRange else { return }
    selectedRange = range
    refresh()
  }

  func refresh() {
    guard let context else { return }
    let now = clock()
    do {
      let configuration = currentConfiguration()
      let (computed, snapshot) = try computeInsights(in: context, at: now, configuration: configuration)
      let rangeStart = calculator.interval(for: selectedRange.insightsRange, at: now).start
      let usage = try Self.fetchAppUsage(in: context, from: rangeStart)
      hasStoredData = try Self.containsRecords(in: context) || liveActivity() != nil
      present(computed, snapshot: snapshot, configuration: configuration, usage: usage, now: now)
      loadFailed = false
    } catch {
      loadFailed = true
      logger.error("Insights fetch failed: \(error.localizedDescription, privacy: .public)")
    }
    isLoaded = true
  }

  func clearAllData() {
    do {
      clearOutcome = .cleared(records: try clearData())
    } catch {
      clearOutcome = .failed
      logger.error("Insights clear failed: \(error.localizedDescription, privacy: .public)")
    }
    refresh()
  }

  func dismissClearOutcome() {
    clearOutcome = nil
  }

  func selectWorkBlock(_ blockID: UUID) {
    selectedWorkBlockID = blockID
  }

  private func computeInsights(
    in context: ModelContext, at now: Date, configuration: InsightsConfiguration
  ) throws -> (Insights, TelemetrySnapshot) {
    let range = selectedRange.insightsRange
    var lookback = Self.initialStreakLookbackDays
    while true {
      let start = calculator.fetchStart(for: range, at: now, streakLookbackDays: lookback)
      var snapshot = try Self.fetchSnapshot(in: context, from: start, to: now)
      if let open = liveActivity(), open.end > start { snapshot.activity.append(open) }
      let computed = calculator.compute(range, at: now, data: snapshot, configuration: configuration)
      if computed.streakDays < lookback || lookback >= Self.maximumStreakLookbackDays {
        return (computed, snapshot)
      }
      lookback = min(Self.maximumStreakLookbackDays, lookback * 4)
    }
  }

  static func fetchSnapshot(in context: ModelContext, from lower: Date, to upper: Date) throws -> TelemetrySnapshot {
    let activity = try context.fetch(
      FetchDescriptor<ActivityRecordModel>(
        predicate: #Predicate { $0.end > lower && $0.start < upper }, sortBy: [SortDescriptor(\.start)]))
    let breaks = try context.fetch(
      FetchDescriptor<BreakRecordModel>(predicate: #Predicate { $0.end >= lower && $0.end <= upper }))
    let wellness = try context.fetch(
      FetchDescriptor<WellnessRecordModel>(predicate: #Predicate { $0.at >= lower && $0.at <= upper }))
    return TelemetrySnapshot(
      activity: activity.compactMap { $0.value },
      breaks: breaks.compactMap { $0.value },
      wellness: wellness.compactMap { $0.value })
  }

  static func fetchAppUsage(in context: ModelContext, from lower: Date) throws -> [AppUsageSample] {
    try context.fetch(FetchDescriptor<WorkBlockAppUsage>(predicate: #Predicate { $0.blockEnd >= lower })).map {
      AppUsageSample(
        blockID: $0.blockID,
        blockStart: $0.blockStart,
        blockEnd: $0.blockEnd,
        appName: $0.appName,
        bundleIdentifier: $0.bundleIdentifier,
        activeSeconds: $0.activeSeconds,
        activationCount: $0.activationCount)
    }
  }

  static func containsRecords(in context: ModelContext) throws -> Bool {
    func exists<Model: PersistentModel>(_: Model.Type) throws -> Bool {
      var descriptor = FetchDescriptor<Model>()
      descriptor.fetchLimit = 1
      return try context.fetchCount(descriptor) > 0
    }
    return try exists(ActivityRecordModel.self) || exists(BreakRecordModel.self)
      || exists(WellnessRecordModel.self) || exists(WorkBlockAppUsage.self)
  }

  private func currentConfiguration() -> InsightsConfiguration {
    let profile = defaults.string(forKey: SettingKey.insightScoringProfile).flatMap(ScoringProfile.init(rawValue:))
    let threshold = defaults.double(forKey: SettingKey.interruptionThreshold)
    let usesDayWindow = defaults.bool(forKey: SettingKey.dayProgressEnabled)
    let workday = TimeWindow(
      startMinute: usesDayWindow
        ? defaults.integer(forKey: SettingKey.dayProgressStartMinute) : SettingsCatalog.defaultWorkdayStartMinute,
      endMinute: usesDayWindow
        ? defaults.integer(forKey: SettingKey.dayProgressEndMinute) : SettingsCatalog.defaultWorkdayEndMinute)
    return InsightsConfiguration(
      goals: InsightsGoals(
        focusMinutes: defaults.integer(forKey: SettingKey.dailyFocusGoalMinutes),
        breaks: defaults.integer(forKey: SettingKey.dailyBreakGoalCount),
        wellness: defaults.integer(forKey: SettingKey.dailyWellnessGoalCount)),
      profile: profile ?? .balanced,
      workWindow: workday,
      interruptionThreshold: threshold > 0 ? threshold : SettingsCatalog.interruptionThresholdDefault)
  }

  private func present(
    _ result: Insights,
    snapshot: TelemetrySnapshot,
    configuration: InsightsConfiguration,
    usage: [AppUsageSample],
    now: Date
  ) {
    insights = result
    updateSkipAdvice(from: snapshot)
    lastUpdated = now
    kpis = Self.makeKPIs(for: result, range: selectedRange, configuration: configuration)
    details = Self.makeDetails(for: result, range: selectedRange)
    trend = result.buckets.map { TrendPoint(date: $0.interval.start, minutes: $0.focus / 60) }
    goalLineMinutes =
      selectedRange != .today && defaults.bool(forKey: SettingKey.insightsShowGoalLine)
      ? Double(configuration.goals.focusMinutes) : nil

    let day = calculator.timeline(on: now, at: now, data: snapshot)
    timelineDomain = day.domain
    timelineBlocks = day.segments.enumerated().map { index, segment in
      TimelineBlock(id: index, lane: segment.lane, start: segment.interval.start, end: segment.interval.end)
    }

    let map = calculator.hourlyHeatmap(days: Self.heatmapDays, at: now, active: snapshot.activity)
    heatmapDays = map.days
    heatmap = map.cells.enumerated().map { index, cell in
      HeatPoint(id: index, day: cell.day, hour: cell.hour, minutes: cell.focus / 60)
    }
    heatmapPeakMinutes = (map.peak?.focus ?? 0) / 60

    forecastText =
      defaults.bool(forKey: SettingKey.insightsForecastEnabled) && result.hasData
      ? Self.describe(result.forecast) : nil
    wellnessStats = result.wellnessByKind.map {
      WellnessTypeStat(
        id: $0.kind.rawValue,
        label: $0.kind.localizedName,
        completed: $0.completed,
        total: $0.total,
        completionRate: Self.percent($0.rate))
    }
    buildAppUsageHighlights(usage)
  }

  private func buildAppUsageHighlights(_ usage: [AppUsageSample]) {
    topAppsInRange = Self.topApps(from: usage)

    guard selectedRange == .today else {
      workBlockAppSummaries = []
      selectedWorkBlockID = nil
      return
    }

    workBlockAppSummaries = Self.workBlocks(from: usage)

    if let selectedWorkBlockID, workBlockAppSummaries.contains(where: { $0.id == selectedWorkBlockID }) { return }
    selectedWorkBlockID = workBlockAppSummaries.last?.id
  }
}
