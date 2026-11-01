import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

@Suite(.serialized)
@MainActor
final class SuperZenTests {
  // The test target's TEST_HOST is SuperZen.app itself (see project.pbxproj), so
  // `UserDefaults.standard` inside every test IS the real, live app's UserDefaults
  // domain — not an isolated test double. Individual tests historically saved/restored
  // only the couple of keys they touched (see `restoreDefault`, still used below), but
  // that discipline wasn't applied consistently everywhere, and any test that set e.g.
  // `workDuration`/`breakDuration` to a fixture value without restoring it left that
  // value permanently overwriting the real user's setting the next time the app ran.
  // Swift Testing creates a fresh instance of this suite per `@Test`, so snapshotting
  // every known settings key here and restoring it in `deinit` protects every test
  // automatically, regardless of whether that test remembers to clean up after itself.
  private let allSettingsSnapshot: [String: Any?]

  init() {
    let d = UserDefaults.standard
    allSettingsSnapshot = Dictionary(
      uniqueKeysWithValues: SettingKey.allKeys.map { ($0, d.object(forKey: $0)) })
  }

  deinit {
    let d = UserDefaults.standard
    for (key, value) in allSettingsSnapshot {
      if let value {
        d.set(value, forKey: key)
      } else {
        d.removeObject(forKey: key)
      }
    }
  }

  @Test func appRetainsStateManagerAsStateObject() {
    let app = SuperZenApp()
    let labels = Set(Mirror(reflecting: app).children.compactMap(\.label))
    #expect(labels.contains("_stateManager"))
  }

  @Test func sidebarGroupsCoverEachSectionExactlyOnce() {
    let groupedSections = PreferencesSection.sidebarGroups.flatMap(\.sections)
    #expect(groupedSections.count == PreferencesSection.allCases.count)
    #expect(Set(groupedSections).count == PreferencesSection.allCases.count)
    #expect(groupedSections.first == .general)
    #expect(groupedSections.last == .insights)
  }

  @Test func preferencesSectionRawValueRoundTrip() {
    for section in PreferencesSection.allCases {
      #expect(PreferencesSection(rawValue: section.rawValue) == section)
    }
    #expect(PreferencesSection(rawValue: "NotASection") == nil)
  }

  @Test func insightsEmptyDataIsZeroSafe() throws {
    let viewModel = DashboardViewModel()
    let now = Date()

    viewModel.selectedRange = .today
    viewModel.refresh(now: now, sessions: [], breaks: [], wellness: [])

    #expect(viewModel.focusedMinutes == 0)
    #expect(viewModel.sessionsCount == 0)
    #expect(viewModel.averageSessionMinutes == 0)
    #expect(viewModel.longestSessionMinutes == 0)
    #expect(viewModel.breakCompleted == 0)
    #expect(viewModel.breakTotal == 0)
    #expect(viewModel.wellnessCompleted == 0)
    #expect(viewModel.wellnessTotal == 0)
    #expect(viewModel.chartPoints.count == 24)

    viewModel.selectedRange = .week
    viewModel.refresh(now: now, sessions: [], breaks: [], wellness: [])
    #expect(viewModel.chartPoints.count == 7)
  }

  @Test func insightsTodayAggregationAccuracy() throws {
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: date(startOfDay, hour: 9, minute: 10),
        activeSeconds: 1200
      ),
      DashboardViewModel.SessionSample(
        startTime: date(startOfDay, hour: 9, minute: 45),
        activeSeconds: 600
      ),
      DashboardViewModel.SessionSample(
        startTime: date(startOfDay, hour: 14, minute: 5),
        activeSeconds: 1800
      ),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .today
    viewModel.refresh(now: now, sessions: sessions, breaks: [], wellness: [])

    #expect(viewModel.focusedMinutes == 60)
    #expect(viewModel.sessionsCount == 3)
    #expect(viewModel.averageSessionMinutes == 20)
    #expect(viewModel.longestSessionMinutes == 30)
    #expect(viewModel.chartPoints.count == 24)
    #expect(Int(viewModel.chartPoints.reduce(0) { $0 + $1.minutes }.rounded()) == 60)
    #expect(viewModel.chartPoints.filter { $0.minutes > 0 }.count == 2)
  }

  @Test func insightsWeekAggregationAccuracy() throws {
    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -6, to: todayStart)!,
        activeSeconds: 600
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -3, to: todayStart)!,
        activeSeconds: 1800
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: 0, to: todayStart)!,
        activeSeconds: 1200
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -8, to: todayStart)!,
        activeSeconds: 999
      ),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .week
    viewModel.refresh(now: now, sessions: sessions, breaks: [], wellness: [])

    #expect(viewModel.focusedMinutes == 60)
    #expect(viewModel.sessionsCount == 3)
    #expect(viewModel.averageSessionMinutes == 20)
    #expect(viewModel.longestSessionMinutes == 30)
    #expect(viewModel.chartPoints.count == 7)
    #expect(Int(viewModel.chartPoints.reduce(0) { $0 + $1.minutes }.rounded()) == 60)
    #expect(viewModel.chartPoints.filter { $0.minutes > 0 }.count == 3)
  }

  @Test func insightsCompletionCountsAreCorrect() throws {
    let now = Date()
    let breaks = [
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: false),
    ]
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, action: "dismissed"),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .today
    viewModel.refresh(now: now, sessions: [], breaks: breaks, wellness: wellness)

    #expect(viewModel.breakTotal == 2)
    #expect(viewModel.breakCompleted == 1)
    #expect(viewModel.wellnessTotal == 2)
    #expect(viewModel.wellnessCompleted == 1)
  }

  @Test func insightsRangeToggleSwitchesChartDataset() throws {
    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: date(todayStart, hour: 8, minute: 0),
        activeSeconds: 900
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -2, to: todayStart)!,
        activeSeconds: 900
      ),
    ]

    let viewModel = DashboardViewModel()

    viewModel.selectedRange = .today
    viewModel.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(viewModel.chartPoints.count == 24)
    #expect(viewModel.chartTitle == "Hourly active minutes")

    viewModel.selectedRange = .week
    viewModel.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(viewModel.chartPoints.count == 7)
    #expect(viewModel.chartTitle == "Daily active minutes (last 7 days)")
  }

  @Test func insightsCachedSamplesRecomputeAcrossRanges() throws {
    let calendar = Calendar.current
    let now = Date()
    let start = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: start.addingTimeInterval(9 * 3600),
        activeSeconds: 1200
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -4, to: start)!,
        activeSeconds: 1800
      ),
    ]
    let breaks = [
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(
        timestamp: calendar.date(byAdding: .day, value: -4, to: now)!,
        wasCompleted: false
      ),
    ]

    let viewModel = DashboardViewModel()
    viewModel.seedCacheForTesting(sessions: sessions, breaks: breaks, wellness: [])

    viewModel.selectedRange = .today
    viewModel.refreshForSelectedRange(now: now)
    #expect(viewModel.focusedMinutes == 20)
    #expect(viewModel.breakTotal == 1)

    viewModel.selectedRange = .week
    viewModel.refreshForSelectedRange(now: now)
    #expect(viewModel.focusedMinutes == 50)
    #expect(viewModel.breakTotal == 2)
  }

  @Test func insightsBuildsDailyWorkBlockAppSummaries() throws {
    let dayStart = Calendar.current.startOfDay(for: Date())
    let block1 = UUID()
    let block2 = UUID()
    let appUsage = [
      DashboardViewModel.AppUsageSample(
        blockID: block1,
        blockStart: dayStart.addingTimeInterval(9 * 3600),
        blockEnd: dayStart.addingTimeInterval(9 * 3600 + 1800),
        appName: "Xcode",
        bundleIdentifier: "com.apple.dt.Xcode",
        activeSeconds: 1200,
        activationCount: 2
      ),
      DashboardViewModel.AppUsageSample(
        blockID: block1,
        blockStart: dayStart.addingTimeInterval(9 * 3600),
        blockEnd: dayStart.addingTimeInterval(9 * 3600 + 1800),
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        activeSeconds: 600,
        activationCount: 1
      ),
      DashboardViewModel.AppUsageSample(
        blockID: block2,
        blockStart: dayStart.addingTimeInterval(11 * 3600),
        blockEnd: dayStart.addingTimeInterval(11 * 3600 + 1200),
        appName: "VS Code",
        bundleIdentifier: "com.microsoft.VSCode",
        activeSeconds: 900,
        activationCount: 1
      ),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .today
    viewModel.seedCacheForTesting(sessions: [], breaks: [], wellness: [], appUsage: appUsage)
    viewModel.refreshForSelectedRange(now: dayStart.addingTimeInterval(15 * 3600))

    #expect(viewModel.workBlockAppSummaries.count == 2)
    #expect(viewModel.workBlockAppSummaries.first?.rows.first?.appName == "Xcode")
    #expect(viewModel.workBlockAppSummaries.first?.rows.first?.activeMinutes == 20)
    #expect(viewModel.selectedWorkBlockSummary?.id == viewModel.workBlockAppSummaries.last?.id)

    if let firstBlockID = viewModel.workBlockAppSummaries.first?.id {
      viewModel.selectWorkBlock(firstBlockID)
      #expect(viewModel.selectedWorkBlockSummary?.id == firstBlockID)
    }

    #expect(viewModel.topAppsInRange.first?.appName == "Xcode")
  }

  @Test func insightsMonthRangeAndGoals() throws {
    let defaults = UserDefaults.standard
    let previousFocusGoal = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    let previousBreakGoal = defaults.object(forKey: SettingKey.dailyBreakGoalCount)
    let previousWellnessGoal = defaults.object(forKey: SettingKey.dailyWellnessGoalCount)
    let previousGoalLine = defaults.object(forKey: SettingKey.insightsShowGoalLine)
    defer {
      restoreDefault(previousFocusGoal, key: SettingKey.dailyFocusGoalMinutes)
      restoreDefault(previousBreakGoal, key: SettingKey.dailyBreakGoalCount)
      restoreDefault(previousWellnessGoal, key: SettingKey.dailyWellnessGoalCount)
      restoreDefault(previousGoalLine, key: SettingKey.insightsShowGoalLine)
    }

    defaults.set(120, forKey: SettingKey.dailyFocusGoalMinutes)
    defaults.set(2, forKey: SettingKey.dailyBreakGoalCount)
    defaults.set(3, forKey: SettingKey.dailyWellnessGoalCount)
    defaults.set(true, forKey: SettingKey.insightsShowGoalLine)

    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -2, to: today)!,
        activeSeconds: 3600
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -1, to: today)!,
        activeSeconds: 7200
      ),
      DashboardViewModel.SessionSample(
        startTime: today.addingTimeInterval(9 * 3600),
        activeSeconds: 1800
      ),
    ]
    let breaks = [
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: false),
    ]
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, action: "dismissed"),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .month
    viewModel.refresh(now: now, sessions: sessions, breaks: breaks, wellness: wellness)

    #expect(viewModel.chartPoints.count == 30)
    #expect(viewModel.focusGoalMinutes == 120)
    #expect(viewModel.breakGoalCount == 2)
    #expect(viewModel.wellnessGoalCount == 3)
    #expect(viewModel.chartGoalValue == 120)
    #expect(viewModel.focusGoalProgress > 0)
    #expect(viewModel.breakGoalProgress > 0)
    #expect(viewModel.wellnessGoalProgress > 0)
  }

  @Test func insightsTrendComparisonUsesPreviousEquivalentPeriod() throws {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let thisWeekSessions = [
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -1, to: today)!,
        activeSeconds: 3600
      ),
      DashboardViewModel.SessionSample(
        startTime: today.addingTimeInterval(8 * 3600),
        activeSeconds: 3600
      ),
    ]
    let previousWeekSessions = [
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -8, to: today)!,
        activeSeconds: 1800
      ),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -10, to: today)!,
        activeSeconds: 1800
      ),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .week
    viewModel.refresh(
      now: now,
      sessions: thisWeekSessions + previousWeekSessions,
      breaks: [],
      wellness: []
    )

    #expect(viewModel.trendDeltaPercent == 100)
  }

  @Test func insightsQualityForecastAndWellnessTypeBreakdown() throws {
    let defaults = UserDefaults.standard
    let previousProfile = defaults.object(forKey: SettingKey.insightScoringProfile)
    let previousForecast = defaults.object(forKey: SettingKey.insightsForecastEnabled)
    defer {
      restoreDefault(previousProfile, key: SettingKey.insightScoringProfile)
      restoreDefault(previousForecast, key: SettingKey.insightsForecastEnabled)
    }

    defaults.set("Balanced", forKey: SettingKey.insightScoringProfile)
    defaults.set(true, forKey: SettingKey.insightsForecastEnabled)

    let now = Date()
    let todayStart = Calendar.current.startOfDay(for: now)
    // Anchor sessions to fixed hours today so the test is not sensitive to time-of-day.
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(8 * 3600),
        activeSeconds: 1200,
        idleSeconds: 300,
        interruptions: 1
      ),
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(10 * 3600),
        activeSeconds: 600,
        idleSeconds: 60,
        interruptions: 0
      ),
    ]
    let breaks = [
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: false),
    ]
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "blink", action: "dismissed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "water", action: "completed"),
    ]

    let viewModel = DashboardViewModel()
    viewModel.selectedRange = .today
    viewModel.refresh(now: now, sessions: sessions, breaks: breaks, wellness: wellness)

    #expect(viewModel.idleMinutes == 6)
    #expect(viewModel.interruptionsCount == 1)
    #expect(viewModel.skippedBreakCount == 1)
    #expect(viewModel.focusQualityScore > 0)
    #expect(viewModel.forecastText.isEmpty == false)
    #expect(viewModel.wellnessTypeStats.count == 4)
    #expect(viewModel.wellnessTypeStats.first(where: { $0.id == "posture" })?.completionRate == 100)
  }

  @Test func telemetryPruningRemovesRecordsOutsideRetentionWindow() throws {
    let schema = Schema([
      FocusSession.self,
      BreakEvent.self,
      WellnessEvent.self,
      WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    let service = TelemetryService()
    service.setup(context: context)

    let now = isoDate("2026-02-26T12:00:00Z")
    let oldDate = isoDate("2025-01-01T12:00:00Z")

    let oldSession = FocusSession()
    oldSession.startTime = oldDate
    context.insert(oldSession)

    let oldBreak = BreakEvent(type: "Macro", wasCompleted: true, durationTaken: 300)
    oldBreak.timestamp = oldDate
    context.insert(oldBreak)

    let freshWellness = WellnessEvent(type: "posture", action: "completed")
    freshWellness.timestamp = now
    context.insert(freshWellness)

    let oldAppUsage = WorkBlockAppUsage(
      blockID: UUID(),
      blockStart: oldDate,
      blockEnd: oldDate,
      appName: "Xcode",
      bundleIdentifier: "com.apple.dt.Xcode",
      activeSeconds: 600,
      activationCount: 1
    )
    context.insert(oldAppUsage)

    try context.save()

    let summary = service.pruneHistoricalData(retainingDays: 90, now: now)

    #expect(summary.sessionsDeleted == 1)
    #expect(summary.breaksDeleted == 1)
    #expect(summary.wellnessDeleted == 0)
    #expect(summary.appUsageDeleted == 1)
  }

  @Test func telemetryClearAllDataDeletesAllTelemetryRows() throws {
    let schema = Schema([
      FocusSession.self,
      BreakEvent.self,
      WellnessEvent.self,
      WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    let service = TelemetryService()
    service.setup(context: context)

    let now = isoDate("2026-02-26T12:00:00Z")

    let session = FocusSession()
    session.startTime = now
    context.insert(session)

    let breakEvent = BreakEvent(type: "Micro", wasCompleted: false, durationTaken: 60)
    breakEvent.timestamp = now
    context.insert(breakEvent)

    let wellness = WellnessEvent(type: "blink", action: "completed")
    wellness.timestamp = now
    context.insert(wellness)

    let usage = WorkBlockAppUsage(
      blockID: UUID(),
      blockStart: now,
      blockEnd: now,
      appName: "Xcode",
      bundleIdentifier: "com.apple.dt.Xcode",
      activeSeconds: 120,
      activationCount: 1
    )
    context.insert(usage)

    try context.save()

    let summary = service.clearAllTelemetryData()

    #expect(summary.sessionsDeleted == 1)
    #expect(summary.breaksDeleted == 1)
    #expect(summary.wellnessDeleted == 1)
    #expect(summary.appUsageDeleted == 1)
  }

  // MARK: - AppStatus Tests

  @Test func appStatusDescriptionMapping() {
    #expect(AppStatus.active.description == "Focusing")
    #expect(AppStatus.nudge.description == "Break soon")
    #expect(AppStatus.onBreak.description == "On Break")
    #expect(AppStatus.wellness(type: .posture).description == "Wellness: Posture")
    #expect(AppStatus.wellness(type: .blink).description == "Wellness: Blink")
    #expect(AppStatus.wellness(type: .water).description == "Wellness: Water")
    #expect(AppStatus.wellness(type: .affirmation).description == "Affirmation")
    #expect(AppStatus.paused.description == "Paused")
  }

  @Test func nudgeDescriptionIsBreakSoon() {
    // Regression: previously fell through to default case and returned "Paused"
    #expect(AppStatus.nudge.description == "Break soon")
    #expect(AppStatus.nudge.description != AppStatus.paused.description)
  }

  @Test func appStatusIsPausedOnlyForPaused() {
    #expect(AppStatus.paused.isPaused == true)
    #expect(AppStatus.active.isPaused == false)
    #expect(AppStatus.nudge.isPaused == false)
    #expect(AppStatus.onBreak.isPaused == false)
    #expect(AppStatus.wellness(type: .posture).isPaused == false)
    #expect(AppStatus.wellness(type: .affirmation).isPaused == false)
  }

  @Test func wellnessTypeDisplayDurations() {
    // posture/blink/water: 0.75s flash — intentionally short for power users
    #expect(AppStatus.WellnessType.posture.displayDuration == 0.75)
    #expect(AppStatus.WellnessType.blink.displayDuration == 0.75)
    #expect(AppStatus.WellnessType.water.displayDuration == 0.75)
    // affirmation: 2.0s — text must be read
    #expect(AppStatus.WellnessType.affirmation.displayDuration == 2.0)
  }

  @Test func wellnessTypeRawValues() {
    #expect(AppStatus.WellnessType.posture.rawValue == "posture")
    #expect(AppStatus.WellnessType.blink.rawValue == "blink")
    #expect(AppStatus.WellnessType.water.rawValue == "water")
    #expect(AppStatus.WellnessType.affirmation.rawValue == "affirmation")
  }

  @Test func appStatusWellnessEquality() {
    #expect(AppStatus.wellness(type: .posture) == AppStatus.wellness(type: .posture))
    #expect(AppStatus.wellness(type: .posture) != AppStatus.wellness(type: .blink))
    #expect(AppStatus.wellness(type: .water) != AppStatus.wellness(type: .affirmation))
    #expect(AppStatus.active != AppStatus.paused)
  }

  // MARK: - BreakDifficulty Tests

  @Test func breakDifficultyAllCasesCount() {
    #expect(BreakDifficulty.allCases.count == 3)
  }

  @Test func breakDifficultyRawValues() {
    #expect(BreakDifficulty.casual.rawValue == "Casual")
    #expect(BreakDifficulty.balanced.rawValue == "Balanced")
    #expect(BreakDifficulty.hardcore.rawValue == "Hardcore")
  }

  @Test func breakDifficultyRoundTrip() {
    for difficulty in BreakDifficulty.allCases {
      #expect(BreakDifficulty(rawValue: difficulty.rawValue) == difficulty)
    }
    #expect(BreakDifficulty(rawValue: "unknown") == nil)
  }

  // MARK: - TelemetryService: Interruption Counting Fix (2026-06-29)

  @Test func interruptionCountsAccumulateAcrossHeartbeats() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    // Simulate 35 × 1-second idle heartbeats; default threshold is 30s
    for _ in 0..<35 {
      service.recordIdleTime(seconds: 1.0, isFocusSession: true)
    }

    let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.count == 1)
    #expect(sessions.first?.interruptions == 1)
    #expect(sessions.first?.idleSeconds == 35.0)
  }

  @Test func interruptionNotDoubleCountedInSingleIdleRun() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    // 60 × 1-second idle — crosses 30s threshold once, must count only ONCE
    for _ in 0..<60 {
      service.recordIdleTime(seconds: 1.0, isFocusSession: true)
    }

    let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.first?.interruptions == 1)
  }

  @Test func interruptionResetsAfterActivityResumed() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    for _ in 0..<35 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }
    service.recordActiveTime(seconds: 5.0)  // resets idle run counter
    for _ in 0..<35 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }

    let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.first?.interruptions == 2)
  }

  @Test func interruptionThresholdHonoredFromUserDefaults() throws {
    let defaults = UserDefaults.standard
    let previousThreshold = defaults.object(forKey: SettingKey.interruptionThreshold)
    defer { restoreDefault(previousThreshold, key: SettingKey.interruptionThreshold) }
    defaults.set(10.0, forKey: SettingKey.interruptionThreshold)

    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    for _ in 0..<8 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }

    var sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.first?.interruptions == 0)  // 8s < 10s threshold

    for _ in 0..<3 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }
    sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.first?.interruptions == 1)  // 11s > 10s threshold
  }

  @Test func endFocusSessionResetsInterruptionState() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    for _ in 0..<35 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }
    service.endFocusSession()  // resets idleRunSeconds + interruptionCounted

    service.startFocusSession()
    for _ in 0..<15 { service.recordIdleTime(seconds: 1.0, isFocusSession: true) }

    let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.count == 2)
    let second = sessions.max(by: { $0.startTime < $1.startTime })
    #expect(second?.interruptions == 0)  // 15s < 30s threshold on fresh state
  }

  @Test func startFocusSessionIsIdempotent() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.startFocusSession()
    service.startFocusSession()  // no-op
    service.startFocusSession()  // no-op

    let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.count == 1)
  }

  @Test func logBreakRecordsCompletedStatus() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.logBreak(type: "Macro", completed: true, duration: 300)

    let breaks = try container.mainContext.fetch(FetchDescriptor<BreakEvent>())
    #expect(breaks.count == 1)
    #expect(breaks.first?.wasCompleted == true)
    #expect(breaks.first?.type == "Macro")
    #expect(breaks.first?.durationTaken == 300)
  }

  @Test func logBreakRecordsSkippedStatus() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.logBreak(type: "Macro", completed: false, duration: 45)

    let breaks = try container.mainContext.fetch(FetchDescriptor<BreakEvent>())
    #expect(breaks.count == 1)
    #expect(breaks.first?.wasCompleted == false)
    #expect(breaks.first?.durationTaken == 45)
  }

  @Test func logWellnessRecordsTypeAndAction() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    service.logWellness(type: .posture, action: "completed")
    service.logWellness(type: .blink, action: "dismissed")

    let events = try container.mainContext.fetch(FetchDescriptor<WellnessEvent>())
    #expect(events.count == 2)
    #expect(events.first { $0.action == "completed" }?.type == "posture")
    #expect(events.first { $0.action == "dismissed" }?.type == "blink")
  }

  @Test func pruneKeepsFreshRecordsIntact() throws {
    let schema = Schema([
      FocusSession.self, BreakEvent.self, WellnessEvent.self, WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let service = TelemetryService()
    service.setup(context: container.mainContext)

    let now = isoDate("2026-02-26T12:00:00Z")
    let recent = isoDate("2026-02-20T12:00:00Z")  // 6 days ago — within 90-day window

    let session = FocusSession()
    session.startTime = recent
    container.mainContext.insert(session)
    try container.mainContext.save()

    let summary = service.pruneHistoricalData(retainingDays: 90, now: now)
    #expect(summary.sessionsDeleted == 0)
    #expect(try container.mainContext.fetch(FetchDescriptor<FocusSession>()).count == 1)
  }

  // MARK: - PruneSummary

  @Test func pruneSummaryTotalDeletedIsCorrectSum() {
    let s = TelemetryService.PruneSummary(
      sessionsDeleted: 5, breaksDeleted: 3, wellnessDeleted: 7, appUsageDeleted: 2)
    #expect(s.totalDeleted == 17)
  }

  @Test func pruneSummaryZeroTotalWhenAllZero() {
    let s = TelemetryService.PruneSummary(
      sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0, appUsageDeleted: 0)
    #expect(s.totalDeleted == 0)
  }

  // MARK: - SettingsCatalog Tests

  @Test func settingsCatalogWorkDurationOptionsAllPositive() {
    #expect(!SettingsCatalog.workDurationOptions.isEmpty)
    for (label, duration) in SettingsCatalog.workDurationOptions {
      #expect(!label.isEmpty)
      #expect(duration > 0)
    }
  }

  @Test func settingsCatalogBreakDurationOptionsAllPositive() {
    #expect(!SettingsCatalog.breakDurationOptions.isEmpty)
    for (label, duration) in SettingsCatalog.breakDurationOptions {
      #expect(!label.isEmpty)
      #expect(duration > 0)
    }
  }

  @Test func settingsCatalogBalancedSkipLockRatiosInValidRange() {
    #expect(!SettingsCatalog.balancedSkipLockOptions.isEmpty)
    for (_, ratio) in SettingsCatalog.balancedSkipLockOptions {
      #expect(ratio > 0.0 && ratio < 1.0)
    }
  }

  @Test func settingsCatalogWellnessMultipliersInValidRange() {
    for (_, multiplier) in SettingsCatalog.wellnessDurationMultiplierOptions {
      #expect(multiplier >= 0.1 && multiplier <= 2.0)
    }
  }

  @Test func settingsCatalogRetentionDaysAllPositive() {
    for days in SettingsCatalog.retentionDaysOptions {
      #expect(days > 0)
    }
  }

  @Test func settingsCatalogDayProgressBarStylesAreKnownKeys() {
    let valid = Set(["bar_label", "bar_only", "label_only", "bar_label_inside"])
    for (_, key) in SettingsCatalog.dayProgressBarStyles {
      #expect(valid.contains(key))
    }
  }

  @Test func settingsCatalogDayProgressMetricsAreKnownKeys() {
    let valid = Set([
      "pct_done", "pct_remaining", "min_elapsed", "min_remaining",
      "hr_elapsed", "hr_remaining", "hr_min_elapsed", "hr_min_remaining",
    ])
    for (_, key) in SettingsCatalog.dayProgressMetrics {
      #expect(valid.contains(key))
    }
  }

  @Test func settingsCatalogScoringProfilesAreValid() {
    #expect(Set(SettingsCatalog.scoringProfiles) == Set(["Balanced", "Deep Focus", "Recovery"]))
  }

  // MARK: - DashboardViewModel: Streak Tests (2026-06-29 fix)

  @Test func streakIsZeroWhenNoDataExists() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(5, forKey: SettingKey.dailyFocusGoalMinutes)

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: Date(), sessions: [], breaks: [], wellness: [])
    #expect(vm.consistencyStreakDays == 0)
  }

  @Test func streakIsZeroWhenOnlyTodayMeetsGoal() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(5, forKey: SettingKey.dailyFocusGoalMinutes)  // 300s goal

    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(9 * 3600), activeSeconds: 600)
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    // Streak starts from yesterday — yesterday is empty → streak = 0
    #expect(vm.consistencyStreakDays == 0)
  }

  @Test func streakCountsConsecutiveDaysFromYesterday() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(5, forKey: SettingKey.dailyFocusGoalMinutes)  // 300s goal

    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = (1...3).map { offset in
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -offset, to: todayStart)!,
        activeSeconds: 600)
    }

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(vm.consistencyStreakDays == 3)
  }

  @Test func streakBreaksOnGapDay() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(5, forKey: SettingKey.dailyFocusGoalMinutes)

    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    // Yesterday ✓, 2 days ago MISSING, 3 days ago ✓ → streak = 1
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -1, to: todayStart)!, activeSeconds: 600),
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -3, to: todayStart)!, activeSeconds: 600),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(vm.consistencyStreakDays == 1)
  }

  @Test func streakIsNotCappedAt30Days() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(5, forKey: SettingKey.dailyFocusGoalMinutes)  // 300s goal

    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = (1...45).compactMap { offset -> DashboardViewModel.SessionSample? in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
        return nil
      }
      return DashboardViewModel.SessionSample(startTime: day, activeSeconds: 600)
    }

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    // Old code capped at 30 — fix removed the cap
    #expect(vm.consistencyStreakDays == 45)
  }

  // MARK: - DashboardViewModel: Additional Coverage

  @Test func insightsBreakCompletionRateIsCorrect() {
    let now = Date()
    let breaks = [
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true),
      DashboardViewModel.BreakSample(timestamp: now, wasCompleted: false),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: [], breaks: breaks, wellness: [])

    #expect(vm.breakTotal == 3)
    #expect(vm.breakCompleted == 2)
    #expect(vm.skippedBreakCount == 1)
    #expect(vm.breakCompletionRate == 67)  // round(2/3 * 100) = 67
  }

  @Test func insightsWellnessCompletionRateIsCorrect() {
    let now = Date()
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "blink", action: "dismissed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "water", action: "dismissed"),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: [], breaks: [], wellness: wellness)

    #expect(vm.wellnessTotal == 4)
    #expect(vm.wellnessCompleted == 2)
    #expect(vm.wellnessCompletionRate == 50)
  }

  @Test func insightsFocusQualityScoreInValidRangeForAllProfiles() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.insightScoringProfile)
    defer { restoreDefault(prev, key: SettingKey.insightScoringProfile) }

    let now = Date()
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: now.addingTimeInterval(-1800), activeSeconds: 1200, idleSeconds: 300,
        interruptions: 2)
    ]
    let breaks = [DashboardViewModel.BreakSample(timestamp: now, wasCompleted: true)]
    let wellness = [DashboardViewModel.WellnessSample(timestamp: now, action: "completed")]

    for profile in SettingsCatalog.scoringProfiles {
      defaults.set(profile, forKey: SettingKey.insightScoringProfile)
      let vm = DashboardViewModel()
      vm.selectedRange = .today
      vm.refresh(now: now, sessions: sessions, breaks: breaks, wellness: wellness)
      #expect(vm.focusQualityScore >= 0)
      #expect(vm.focusQualityScore <= 100)
    }
  }

  @Test func insightsActiveDaysCountDeduplicatesSessionsOnSameDay() {
    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(9 * 3600), activeSeconds: 300),
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(14 * 3600), activeSeconds: 300),  // same day
      DashboardViewModel.SessionSample(
        startTime: calendar.date(byAdding: .day, value: -1, to: todayStart)!, activeSeconds: 300),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .week
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(vm.activeDaysCount == 2)  // today (×2 sessions) + yesterday = 2 distinct days
  }

  @Test func insightsBestBucketLabelIsNoActivityWhenEmpty() {
    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: Date(), sessions: [], breaks: [], wellness: [])
    #expect(vm.bestBucketLabel == "No activity yet")
  }

  @Test func insightsMonthChartHasExactly30Points() {
    let vm = DashboardViewModel()
    vm.selectedRange = .month
    vm.refresh(now: Date(), sessions: [], breaks: [], wellness: [])
    #expect(vm.chartPoints.count == 30)
  }

  @Test func insightsGoalProgressClampsAtOne() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.dailyFocusGoalMinutes)
    defer { restoreDefault(prev, key: SettingKey.dailyFocusGoalMinutes) }
    defaults.set(1, forKey: SettingKey.dailyFocusGoalMinutes)  // 1 minute goal

    let now = Date()
    // Use a fixed hour today so the session is always within the "today" window,
    // even when the test runs right after midnight.
    let todayAt2AM = Calendar.current.startOfDay(for: now).addingTimeInterval(2 * 3600)
    let sessions = [
      DashboardViewModel.SessionSample(startTime: todayAt2AM, activeSeconds: 3600)
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])

    #expect(vm.focusGoalProgress <= 1.0)
    #expect(vm.focusGoalProgress == 1.0)
  }

  @Test func insightsTrendDeltaIsZeroWhenBothPeriodsEmpty() {
    let vm = DashboardViewModel()
    vm.selectedRange = .week
    vm.refresh(now: Date(), sessions: [], breaks: [], wellness: [])
    #expect(vm.trendDeltaPercent == 0)
  }

  @Test func insightsTrendDeltaIs100WhenOnlyCurrentPeriodHasData() {
    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: todayStart.addingTimeInterval(9 * 3600), activeSeconds: 1800)
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .week
    vm.refresh(now: now, sessions: sessions, breaks: [], wellness: [])
    #expect(vm.trendDeltaPercent == 100)
  }

  @Test func insightsWellnessTypeStatsAlwaysHasFourTypes() {
    let now = Date()
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "blink", action: "dismissed"),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: [], breaks: [], wellness: wellness)

    #expect(vm.wellnessTypeStats.count == 4)  // posture, blink, water, affirmation always present
    let ids = vm.wellnessTypeStats.map(\.id)
    #expect(ids.contains("posture"))
    #expect(ids.contains("blink"))
    #expect(ids.contains("water"))
    #expect(ids.contains("affirmation"))
  }

  @Test func insightsWellnessTypeCompletionRatesAreCorrect() {
    let now = Date()
    let wellness = [
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "completed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "posture", action: "dismissed"),
      DashboardViewModel.WellnessSample(timestamp: now, type: "water", action: "completed"),
    ]

    let vm = DashboardViewModel()
    vm.selectedRange = .today
    vm.refresh(now: now, sessions: [], breaks: [], wellness: wellness)

    let posture = vm.wellnessTypeStats.first { $0.id == "posture" }
    let water = vm.wellnessTypeStats.first { $0.id == "water" }
    let blink = vm.wellnessTypeStats.first { $0.id == "blink" }
    #expect(posture?.completionRate == 50)
    #expect(water?.completionRate == 100)
    #expect(blink?.total == 0)
    #expect(blink?.completionRate == 0)
  }

  // MARK: - Bug-fix regression tests

  @Test func registerDefaultsDoesNotOverrideExistingUserValues() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }

    defaults.set(9999.0, forKey: SettingKey.workDuration)
    SettingKey.registerDefaults()  // must NOT overwrite the 9999

    #expect(defaults.double(forKey: SettingKey.workDuration) == 9999.0)
  }

  /// Regression test for a real gap: `customImagePath` was declared as a `SettingKey` and
  /// listed in `allKeys`, but had no entry in `registerDefaults()`'s dictionary literal, so a
  /// fresh install would read `nil` for it instead of a documented default. Registering into
  /// an isolated, guaranteed-empty UserDefaults suite (rather than `.standard`, which already
  /// has persisted values from prior test/app runs that would mask a missing registration)
  /// proves every key in `allKeys` actually gets a registered fallback.
  @Test func registerDefaultsRegistersEveryKey() {
    let suiteName = "com.himudigonda.SuperZenTests.registerDefaultsCompleteness"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    SettingKey.registerDefaults(in: defaults)

    for key in SettingKey.allKeys {
      #expect(defaults.object(forKey: key) != nil, "\(key) has no registered default")
    }
  }

  // MARK: - Onboarding gate

  @Test func onboardingDefaultsToNotCompleted() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.hasCompletedOnboarding)
    defer { restoreDefault(prev, key: SettingKey.hasCompletedOnboarding) }

    // A fresh install (key absent) must default to showing onboarding.
    defaults.removeObject(forKey: SettingKey.hasCompletedOnboarding)
    SettingKey.registerDefaults()
    #expect(defaults.bool(forKey: SettingKey.hasCompletedOnboarding) == false)
  }

  private func date(_ day: Date, hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
  }

  private func isoDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: value) ?? Date()
  }

  private func restoreDefault(_ previousValue: Any?, key: String) {
    if let value = previousValue {
      UserDefaults.standard.set(value, forKey: key)
    } else {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }
}
