import Combine
import Foundation
import OSLog
import SuperZenCore
import SwiftData

@MainActor
final class InsightsViewModel: ObservableObject {
  enum Range: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: Self { self }

    var insightsRange: InsightsRange {
      switch self {
      case .today: return .today
      case .week: return .week
      case .month: return .month
      }
    }

    var title: String {
      switch self {
      case .today: return String(localized: "Today", comment: "Insights range picker")
      case .week: return String(localized: "Week", comment: "Insights range picker")
      case .month: return String(localized: "Month", comment: "Insights range picker")
      }
    }

    var trendTitle: String {
      switch self {
      case .today: return String(localized: "Focus by hour", comment: "Insights trend chart subtitle: today")
      case .week: return String(localized: "Focus per day, last 7 days", comment: "Insights trend chart subtitle: week")
      case .month:
        return String(localized: "Focus per day, last 30 days", comment: "Insights trend chart subtitle: month")
      }
    }

    var trendUnit: Calendar.Component { self == .today ? .hour : .day }
    var dayCount: Int { insightsRange.dayCount }
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
  }

  enum KPIKind: String, CaseIterable {
    case focus
    case breaks
    case streak
    case quality
  }

  struct KPI: Identifiable, Equatable {
    let kind: KPIKind
    let title: String
    let value: String
    let caption: String
    let progress: Double?
    let icon: String

    var id: KPIKind { kind }
  }

  struct DetailStat: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
  }

  struct TrendPoint: Identifiable, Equatable {
    let date: Date
    let minutes: Double

    var id: Date { date }
  }

  struct TimelineBlock: Identifiable, Equatable {
    let id: Int
    let lane: TimelineLane
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
  }

  struct HeatPoint: Identifiable, Equatable {
    let id: Int
    let day: Date
    let hour: Int
    let minutes: Double
  }

  struct WellnessTypeStat: Identifiable, Equatable {
    let id: String
    let label: String
    let completed: Int
    let total: Int
    let completionRate: Int
  }

  struct AppUsageSample {
    let blockID: UUID
    let blockStart: Date
    let blockEnd: Date
    let appName: String
    let bundleIdentifier: String
    let activeSeconds: Double
    let activationCount: Int
  }

  struct WorkBlockAppRow: Identifiable {
    let id: String
    let appName: String
    let activeMinutes: Int
    let activationCount: Int
    let share: Double
  }

  struct WorkBlockAppSummary: Identifiable {
    let id: UUID
    let label: String
    let blockStart: Date
    let timeWindow: String
    let totalMinutes: Int
    let uniqueAppCount: Int
    let rows: [WorkBlockAppRow]
  }

  struct TopAppSummary: Identifiable {
    let id: String
    let appName: String
    let activeMinutes: Int
    let activationCount: Int
  }

  enum ClearOutcome: Equatable {
    case cleared(records: Int)
    case failed
  }

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
  @Published private(set) var clearOutcome: ClearOutcome?
  @Published var selectedWorkBlockID: UUID?

  private let calculator: InsightsCalculator
  private let defaults: UserDefaults
  private let clock: @MainActor () -> Date
  private let liveActivity: @MainActor () -> ActivityInterval?
  private let clearData: @MainActor () throws -> Int
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Insights")
  private var context: ModelContext?
  private var subscriptions = Set<AnyCancellable>()

  init(
    calendar: Calendar = .current,
    defaults: UserDefaults = .standard,
    notificationCenter: NotificationCenter = .default,
    clock: @escaping @MainActor () -> Date = { Date() },
    liveActivity: @escaping @MainActor () -> ActivityInterval? = { TelemetryService.shared.openActivity },
    clearData: @escaping @MainActor () throws -> Int = { try TelemetryService.shared.clearAllTelemetryData().totalDeleted }
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
      return String(localized: "No focus recorded in the last 7 days", comment: "Insights heatmap accessibility summary")
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
    let workday = TimeWindow(
      startMinute: defaults.integer(forKey: SettingKey.dayProgressStartMinute),
      endMinute: defaults.integer(forKey: SettingKey.dayProgressEndMinute))
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
        label: $0.kind.rawValue.capitalized,
        completed: $0.completed,
        total: $0.total,
        completionRate: Self.percent($0.rate))
    }
    buildAppUsageHighlights(usage)
  }

  static func makeKPIs(for result: Insights, range: Range, configuration: InsightsConfiguration) -> [KPI] {
    let days = range.dayCount
    let focusGoal = configuration.goals.focusSeconds * Double(days)
    let breakGoal = configuration.goals.breaks * days
    return [
      KPI(
        kind: .focus,
        title: String(localized: "Focus", comment: "Insights KPI title"),
        value: InsightsFormat.duration(result.focus),
        caption: String(
          localized: "of \(InsightsFormat.duration(focusGoal)) goal",
          comment: "Insights KPI caption: focus goal for the selected range"),
        progress: result.focusGoalProgress,
        icon: "target"),
      KPI(
        kind: .breaks,
        title: String(localized: "Breaks taken", comment: "Insights KPI title"),
        value: "\(result.breaksTaken)",
        caption: String(
          localized: "Goal \(breakGoal), \(result.breaksSkipped) skipped",
          comment: "Insights KPI caption: break goal and skipped breaks"),
        progress: result.breakGoalProgress,
        icon: "eye"),
      KPI(
        kind: .streak,
        title: String(localized: "Streak", comment: "Insights KPI title"),
        value: String(
          localized: "\(result.streakDays) days", comment: "Insights KPI value: consecutive days at focus goal"),
        caption: String(localized: "Days in a row at your focus goal", comment: "Insights KPI caption"),
        progress: nil,
        icon: "flame"),
      KPI(
        kind: .quality,
        title: String(localized: "Quality", comment: "Insights KPI title"),
        value: result.hasData ? "\(result.qualityScore)" : InsightsFormat.noValue,
        caption: String(
          localized: "\(SettingsCatalog.scoringProfileDisplayName(configuration.profile.rawValue)) score out of 100",
          comment: "Insights KPI caption: scoring profile"),
        progress: result.hasData ? Double(result.qualityScore) / 100 : nil,
        icon: "checkmark.seal"),
    ]
  }

  static func makeDetails(for result: Insights, range: Range) -> [DetailStat] {
    [
      DetailStat(
        id: "sessions", title: String(localized: "Sessions", comment: "Insights detail title"),
        value: "\(result.sessions)", icon: "square.stack"),
      DetailStat(
        id: "average", title: String(localized: "Average session", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.averageSession), icon: "equal.circle"),
      DetailStat(
        id: "longest", title: String(localized: "Longest session", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.longestSession), icon: "timer"),
      DetailStat(
        id: "idle", title: String(localized: "Idle time", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.idle), icon: "pause.circle"),
      DetailStat(
        id: "interruptions", title: String(localized: "Interruptions", comment: "Insights detail title"),
        value: "\(result.interruptions)", icon: "waveform.path.ecg"),
      DetailStat(
        id: "trend", title: String(localized: "Versus previous period", comment: "Insights detail title"),
        value: InsightsFormat.trend(result.trend), icon: "chart.line.uptrend.xyaxis"),
      DetailStat(
        id: "best", title: String(localized: "Best period", comment: "Insights detail title"),
        value: result.bestBucket.map { InsightsFormat.bucket($0.interval.start, range: range) }
          ?? String(localized: "None yet", comment: "Insights best period placeholder"),
        icon: "sparkles"),
      DetailStat(
        id: "wellness", title: String(localized: "Wellness done", comment: "Insights detail title"),
        value: "\(result.wellnessCompleted)/\(result.wellnessTotal)", icon: "heart"),
    ]
  }

  static func percent(_ fraction: Double?) -> Int {
    Int(((fraction ?? 0) * 100).rounded())
  }

  static func describe(_ forecast: Forecast) -> String {
    let minutes = { (seconds: TimeInterval) in InsightsFormat.duration(seconds) }
    switch forecast {
    case .goalMet:
      return String(localized: "Focus goal reached for today.", comment: "Insights forecast")
    case .beforeWorkday(let needed):
      return String(
        localized: "Your workday has not started. Today's goal needs \(minutes(needed)) of focus.",
        comment: "Insights forecast")
    case .gatheringPace(let needed):
      return String(
        localized: "\(minutes(needed)) more focus to reach today's goal.", comment: "Insights forecast")
    case .onTrack(let eta):
      return String(
        localized: "On pace to reach your goal around \(eta.formatted(.dateTime.hour().minute())).",
        comment: "Insights forecast")
    case .shortfall(let projected, let goal):
      return String(
        localized: "At this pace you will reach about \(minutes(projected)) of your \(minutes(goal)) goal by end of day.",
        comment: "Insights forecast")
    case .workdayOver(let shortBy):
      return String(
        localized: "Workday over, \(minutes(shortBy)) short of today's goal.", comment: "Insights forecast")
    case .pace(let delta):
      let gap = abs(delta).formatted(.percent.precision(.fractionLength(0)))
      return delta >= 0
        ? String(localized: "Ahead of pace by \(gap).", comment: "Insights forecast")
        : String(localized: "Behind pace by \(gap).", comment: "Insights forecast")
    }
  }

  private func buildAppUsageHighlights(_ usage: [AppUsageSample]) {
    topAppsInRange = Dictionary(grouping: usage, by: \.appName)
      .map { appName, rows in
        TopAppSummary(
          id: appName,
          appName: appName,
          activeMinutes: Int(rows.reduce(0.0) { $0 + $1.activeSeconds } / 60),
          activationCount: rows.reduce(0) { $0 + $1.activationCount })
      }
      .sorted { ($0.activeMinutes, $0.activationCount) > ($1.activeMinutes, $1.activationCount) }
      .prefix(8)
      .map { $0 }

    guard selectedRange == .today else {
      workBlockAppSummaries = []
      selectedWorkBlockID = nil
      return
    }

    let blocks = Dictionary(grouping: usage, by: \.blockID)
      .compactMap { blockID, rows in Self.summarize(blockID: blockID, rows: rows) }
      .sorted { $0.blockStart < $1.blockStart }

    workBlockAppSummaries = blocks.enumerated().map { index, block in
      WorkBlockAppSummary(
        id: block.id,
        label: String(localized: "Work block \(index + 1)", comment: "Insights: numbered work block name"),
        blockStart: block.blockStart,
        timeWindow: block.timeWindow,
        totalMinutes: block.totalMinutes,
        uniqueAppCount: block.uniqueAppCount,
        rows: block.rows)
    }

    if let selectedWorkBlockID, workBlockAppSummaries.contains(where: { $0.id == selectedWorkBlockID }) { return }
    selectedWorkBlockID = workBlockAppSummaries.last?.id
  }

  private static func summarize(blockID: UUID, rows: [AppUsageSample]) -> WorkBlockAppSummary? {
    guard let blockStart = rows.map(\.blockStart).min(), let blockEnd = rows.map(\.blockEnd).max() else { return nil }
    let totalSeconds = rows.reduce(0.0) { $0 + $1.activeSeconds }
    guard totalSeconds > 0 else { return nil }
    let appRows = Dictionary(grouping: rows, by: \.appName)
      .map { appName, values in
        let seconds = values.reduce(0.0) { $0 + $1.activeSeconds }
        return WorkBlockAppRow(
          id: "\(blockID.uuidString)-\(values.first?.bundleIdentifier ?? appName)",
          appName: appName,
          activeMinutes: Int(seconds / 60),
          activationCount: values.reduce(0) { $0 + $1.activationCount },
          share: seconds / totalSeconds)
      }
      .sorted { ($0.activeMinutes, $0.activationCount) > ($1.activeMinutes, $1.activationCount) }
    return WorkBlockAppSummary(
      id: blockID,
      label: "",
      blockStart: blockStart,
      timeWindow: "\(blockStart.formatted(.dateTime.hour().minute())) to \(blockEnd.formatted(.dateTime.hour().minute()))",
      totalMinutes: Int(totalSeconds / 60),
      uniqueAppCount: appRows.count,
      rows: Array(appRows.prefix(5)))
  }
}

extension TimelineLane {
  var title: String {
    switch self {
    case .focus: return String(localized: "Focus", comment: "Insights timeline lane")
    case .idle: return String(localized: "Idle", comment: "Insights timeline lane")
    case .rest: return String(localized: "Breaks", comment: "Insights timeline lane")
    }
  }
}
