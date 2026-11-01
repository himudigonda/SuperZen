import Combine
import Foundation
import OSLog
import SuperZenCore
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
  enum Range: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var id: Self { self }

    var insightsRange: InsightsRange {
      switch self {
      case .today: return .today
      case .week: return .week
      case .month: return .month
      }
    }

    var chartTitle: String {
      switch self {
      case .today:
        return String(localized: "Hourly active minutes", comment: "Insights chart title: today")
      case .week:
        return String(
          localized: "Daily active minutes (last 7 days)", comment: "Insights chart title: week")
      case .month:
        return String(
          localized: "Daily active minutes (last 30 days)", comment: "Insights chart title: month")
      }
    }

    var dayCount: Int { insightsRange.dayCount }
  }

  struct ChartPoint: Identifiable, Equatable {
    let id: String
    let label: String
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

  static let initialStreakLookbackDays = 35
  static let maximumStreakLookbackDays = 3650

  @Published var selectedRange: Range = .today
  @Published private(set) var insights: Insights?

  @Published var focusedMinutes: Int = 0
  @Published var sessionsCount: Int = 0
  @Published var averageSessionMinutes: Int = 0
  @Published var longestSessionMinutes: Int = 0
  @Published var breakCompleted: Int = 0
  @Published var breakTotal: Int = 0
  @Published var wellnessCompleted: Int = 0
  @Published var wellnessTotal: Int = 0
  @Published var breakCompletionRate: Int = 0
  @Published var wellnessCompletionRate: Int = 0
  @Published var activeDaysCount: Int = 0
  @Published var bestBucketLabel: String = DashboardViewModel.noActivityLabel
  @Published var trendDeltaPercent: Int = 0
  @Published var trendAvailable: Bool = false
  @Published var consistencyStreakDays: Int = 0
  @Published var idleMinutes: Int = 0
  @Published var interruptionsCount: Int = 0
  @Published var skippedBreakCount: Int = 0
  @Published var focusQualityScore: Int = 50
  @Published var forecastText: String = ""
  @Published var wellnessTypeStats: [WellnessTypeStat] = []
  @Published var focusGoalMinutes: Int = SettingsCatalog.dailyFocusGoalDefault
  @Published var breakGoalCount: Int = SettingsCatalog.dailyBreakGoalDefault
  @Published var wellnessGoalCount: Int = SettingsCatalog.dailyWellnessGoalDefault
  @Published var focusGoalProgress: Double = 0
  @Published var breakGoalProgress: Double = 0
  @Published var wellnessGoalProgress: Double = 0
  @Published var showGoalLine: Bool = true
  @Published var chartGoalValue: Double?
  @Published var chartPoints: [ChartPoint] = []
  @Published var workBlockAppSummaries: [WorkBlockAppSummary] = []
  @Published var selectedWorkBlockID: UUID?
  @Published var topAppsInRange: [TopAppSummary] = []

  private static let noActivityLabel = String(
    localized: "No activity yet",
    comment: "Insights: default best-period label when there is no data")

  private let calculator: InsightsCalculator
  private let defaults: UserDefaults
  private let liveActivity: @MainActor () -> ActivityInterval?
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Insights")
  private var context: ModelContext?

  init(
    calendar: Calendar = .current,
    defaults: UserDefaults = .standard,
    liveActivity: @escaping @MainActor () -> ActivityInterval? = { TelemetryService.shared.openActivity }
  ) {
    calculator = InsightsCalculator(calendar: calendar)
    self.defaults = defaults
    self.liveActivity = liveActivity
  }

  var chartTitle: String { selectedRange.chartTitle }
  var selectedWorkBlockSummary: WorkBlockAppSummary? {
    guard let selectedWorkBlockID else { return workBlockAppSummaries.last }
    return workBlockAppSummaries.first(where: { $0.id == selectedWorkBlockID })
  }

  func load(context: ModelContext, now: Date = Date()) {
    self.context = context
    if context === TelemetryService.shared.context { TelemetryService.shared.saveNow() }
    refreshForSelectedRange(now: now)
  }

  func refreshForSelectedRange(now: Date = Date()) {
    if selectedRange != .today { selectedWorkBlockID = nil }
    guard let context else { return }
    do {
      let configuration = currentConfiguration()
      let computed = try computeInsights(in: context, at: now, configuration: configuration)
      let rangeStart = calculator.interval(for: selectedRange.insightsRange, at: now).start
      let usage = try Self.fetchAppUsage(in: context, from: rangeStart)
      apply(computed, configuration: configuration, appUsage: usage)
    } catch {
      logger.error("Insights fetch failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func computeInsights(
    in context: ModelContext, at now: Date, configuration: InsightsConfiguration
  ) throws -> Insights {
    let range = selectedRange.insightsRange
    var lookback = Self.initialStreakLookbackDays
    while true {
      let start = calculator.fetchStart(for: range, at: now, streakLookbackDays: lookback)
      var snapshot = try Self.fetchSnapshot(in: context, from: start, to: now)
      if let open = liveActivity(), open.end > start { snapshot.activity.append(open) }
      let computed = calculator.compute(range, at: now, data: snapshot, configuration: configuration)
      if computed.streakDays < lookback || lookback >= Self.maximumStreakLookbackDays { return computed }
      lookback = min(Self.maximumStreakLookbackDays, lookback * 4)
    }
  }

  func refresh(now: Date, data: TelemetrySnapshot, appUsage: [AppUsageSample] = []) {
    let configuration = currentConfiguration()
    apply(
      calculator.compute(selectedRange.insightsRange, at: now, data: data, configuration: configuration),
      configuration: configuration,
      appUsage: appUsage)
  }

  func selectWorkBlock(_ blockID: UUID) {
    selectedWorkBlockID = blockID
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

  private func currentConfiguration() -> InsightsConfiguration {
    focusGoalMinutes = max(1, defaults.integer(forKey: SettingKey.dailyFocusGoalMinutes))
    breakGoalCount = max(1, defaults.integer(forKey: SettingKey.dailyBreakGoalCount))
    wellnessGoalCount = max(1, defaults.integer(forKey: SettingKey.dailyWellnessGoalCount))
    showGoalLine = defaults.bool(forKey: SettingKey.insightsShowGoalLine)
    let profile = defaults.string(forKey: SettingKey.insightScoringProfile).flatMap(ScoringProfile.init(rawValue:))
    let threshold = defaults.double(forKey: SettingKey.interruptionThreshold)
    let workday = TimeWindow(
      startMinute: defaults.integer(forKey: SettingKey.dayProgressStartMinute),
      endMinute: defaults.integer(forKey: SettingKey.dayProgressEndMinute))
    return InsightsConfiguration(
      goals: InsightsGoals(focusMinutes: focusGoalMinutes, breaks: breakGoalCount, wellness: wellnessGoalCount),
      profile: profile ?? .balanced,
      workWindow: workday,
      interruptionThreshold: threshold > 0 ? threshold : SettingsCatalog.interruptionThresholdDefault)
  }

  private func apply(_ result: Insights, configuration: InsightsConfiguration, appUsage: [AppUsageSample]) {
    insights = result
    focusedMinutes = Self.minutes(result.focus)
    idleMinutes = Self.minutes(result.idle)
    sessionsCount = result.sessions
    averageSessionMinutes = Self.minutes(result.averageSession)
    longestSessionMinutes = Self.minutes(result.longestSession)
    interruptionsCount = result.interruptions
    breakCompleted = result.breaksTaken
    skippedBreakCount = result.breaksSkipped
    breakTotal = result.breaksTaken + result.breaksSkipped
    breakCompletionRate = Self.percent(result.breakRate)
    wellnessCompleted = result.wellnessCompleted
    wellnessTotal = result.wellnessTotal
    wellnessCompletionRate = Self.percent(result.wellnessRate)
    wellnessTypeStats = result.wellnessByKind.map {
      WellnessTypeStat(
        id: $0.kind.rawValue,
        label: $0.kind.rawValue.capitalized,
        completed: $0.completed,
        total: $0.total,
        completionRate: Self.percent($0.rate))
    }
    focusGoalProgress = result.focusGoalProgress
    breakGoalProgress = result.breakGoalProgress
    wellnessGoalProgress = result.wellnessGoalProgress
    focusQualityScore = result.qualityScore
    consistencyStreakDays = result.streakDays
    activeDaysCount = result.activeDays
    trendAvailable = result.trend != nil
    trendDeltaPercent = Self.percent(result.trend)
    forecastText =
      defaults.bool(forKey: SettingKey.insightsForecastEnabled)
      ? Self.describe(result.forecast) : "Forecast disabled in settings."

    chartPoints = result.buckets.enumerated().map { index, bucket in
      ChartPoint(
        id: "\(selectedRange.rawValue)-\(index)",
        label: label(for: bucket.interval.start),
        minutes: bucket.focus / 60)
    }
    let goalMinutes = Double(configuration.goals.focusMinutes)
    chartGoalValue = showGoalLine ? (selectedRange == .today ? max(1, goalMinutes / 8) : goalMinutes) : nil
    bestBucketLabel = result.bestBucket.map { label(for: $0.interval.start) } ?? Self.noActivityLabel
    buildAppUsageHighlights(appUsage)
  }

  private func label(for date: Date) -> String {
    switch selectedRange {
    case .today: return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    case .week: return date.formatted(.dateTime.weekday(.abbreviated))
    case .month: return date.formatted(.dateTime.day(.defaultDigits))
    }
  }

  static func minutes(_ seconds: TimeInterval) -> Int {
    Int((seconds / 60).rounded(.down))
  }

  static func percent(_ fraction: Double?) -> Int {
    Int(((fraction ?? 0) * 100).rounded())
  }

  static func describe(_ forecast: Forecast) -> String {
    switch forecast {
    case .goalMet:
      return "Focus goal already achieved today."
    case .beforeWorkday(let needed):
      return "Your workday hasn't started yet. Today's goal needs \(minutes(needed))m of focus."
    case .gatheringPace(let needed):
      return "Need \(minutes(needed))m more focused time to hit today's goal."
    case .onTrack(let eta):
      return "At current pace, you'll hit the goal around \(eta.formatted(.dateTime.hour().minute()))."
    case .shortfall(let projected, let goal):
      return "At current pace you'll reach about \(minutes(projected))m of your \(minutes(goal))m goal by end of workday."
    case .workdayOver(let shortBy):
      return "Workday is over, \(minutes(shortBy))m short of today's goal."
    case .pace(let delta):
      let points = Int((abs(delta) * 100).rounded())
      return delta >= 0 ? "You're ahead of pace by \(points)%." : "You're behind pace by \(points)%."
    }
  }

  private func buildAppUsageHighlights(_ usage: [AppUsageSample]) {
    let groupedByApp = Dictionary(grouping: usage, by: \.appName)
    topAppsInRange =
      groupedByApp
      .map { appName, rows in
        TopAppSummary(
          id: appName,
          appName: appName,
          activeMinutes: Int(rows.reduce(0.0) { $0 + $1.activeSeconds } / 60.0),
          activationCount: rows.reduce(0) { $0 + $1.activationCount }
        )
      }
      .sorted {
        if $0.activeMinutes == $1.activeMinutes {
          return $0.activationCount > $1.activationCount
        }
        return $0.activeMinutes > $1.activeMinutes
      }
      .prefix(8)
      .map { $0 }

    guard selectedRange == .today else {
      workBlockAppSummaries = []
      selectedWorkBlockID = nil
      return
    }

    let groupedByBlock = Dictionary(grouping: usage, by: \.blockID)
    let blocks =
      groupedByBlock
      .compactMap { blockID, rows -> WorkBlockAppSummary? in
        guard let first = rows.first else { return nil }
        let blockStart = rows.map(\.blockStart).min() ?? first.blockStart
        let blockEnd = rows.map(\.blockEnd).max() ?? first.blockEnd
        let totalSeconds = rows.reduce(0.0) { $0 + $1.activeSeconds }
        let totalMinutes = Int(totalSeconds / 60.0)
        guard totalSeconds > 0 else { return nil }

        let rowsByApp = Dictionary(grouping: rows, by: \.appName)
        let appRows =
          rowsByApp
          .map { appName, values in
            let appSeconds = values.reduce(0.0) { $0 + $1.activeSeconds }
            let appMinutes = Int(appSeconds / 60.0)
            let activations = values.reduce(0) { $0 + $1.activationCount }
            let key = values.map(\.bundleIdentifier).first ?? appName
            return WorkBlockAppRow(
              id: "\(blockID.uuidString)-\(key)",
              appName: appName,
              activeMinutes: appMinutes,
              activationCount: activations,
              share: appSeconds / totalSeconds
            )
          }
          .sorted { lhs, rhs in
            if lhs.activeMinutes == rhs.activeMinutes {
              return lhs.activationCount > rhs.activationCount
            }
            return lhs.activeMinutes > rhs.activeMinutes
          }

        let startText = blockStart.formatted(.dateTime.hour().minute())
        let endText = blockEnd.formatted(.dateTime.hour().minute())
        return WorkBlockAppSummary(
          id: blockID,
          label: String(
            localized: "Work block", comment: "Insights: unlabeled work block fallback name"),
          blockStart: blockStart,
          timeWindow: "\(startText) - \(endText)",
          totalMinutes: totalMinutes,
          uniqueAppCount: appRows.count,
          rows: appRows.prefix(5).map { $0 }
        )
      }
      .sorted { $0.blockStart < $1.blockStart }

    workBlockAppSummaries = blocks.enumerated().map { index, block in
      WorkBlockAppSummary(
        id: block.id,
        label: String(
          localized: "Work block \(index + 1)", comment: "Insights: numbered work block name"),
        blockStart: block.blockStart,
        timeWindow: block.timeWindow,
        totalMinutes: block.totalMinutes,
        uniqueAppCount: block.uniqueAppCount,
        rows: block.rows
      )
    }

    let exists = workBlockAppSummaries.contains { $0.id == selectedWorkBlockID }
    if selectedWorkBlockID != nil, exists {
      return
    }
    selectedWorkBlockID = workBlockAppSummaries.last?.id
  }
}
