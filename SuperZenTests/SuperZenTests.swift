import Foundation
import SwiftData
import Testing

@testable import SuperZen

@Suite(.serialized)
@MainActor
struct SuperZenTests {
  @Test func stateTransitions() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    defer {
      restoreDefault(prevWork, key: SettingKey.workDuration)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
    }
    let stateManager = StateManager()
    stateManager.workDuration = 1200
    stateManager.breakDuration = 60

    // Initial state
    #expect(stateManager.status == .active)

    // Transition to onBreak
    stateManager.transition(to: .onBreak)
    #expect(stateManager.status == .onBreak)
    #expect(abs(stateManager.timeRemaining - stateManager.breakDuration) < 1.0)

    // Transition back to active
    stateManager.transition(to: .active)
    #expect(stateManager.status == .active)
    #expect(abs(stateManager.timeRemaining - stateManager.workDuration) < 1.0)
  }

  @Test func wellnessTransition() {
    let defaults = UserDefaults.standard
    let previousMultiplier = defaults.object(forKey: SettingKey.wellnessDurationMultiplier)
    defer { restoreDefault(previousMultiplier, key: SettingKey.wellnessDurationMultiplier) }
    defaults.set(1.0, forKey: SettingKey.wellnessDurationMultiplier)

    let stateManager = StateManager()
    stateManager.workDuration = 1200
    let savedTime = stateManager.timeRemaining

    stateManager.transition(to: .wellness(type: .posture))
    #expect(stateManager.status == .wellness(type: .posture))
    #expect(abs(stateManager.timeRemaining - 0.75) < 0.1)

    stateManager.transition(to: .active)
    #expect(stateManager.status == .active)
    #expect(abs(stateManager.timeRemaining - savedTime) < 1.0)
  }

  @Test func pauseToggle() {
    let stateManager = StateManager()

    // Initial state
    #expect(stateManager.status == .active)

    // Pause
    stateManager.togglePause()
    #expect(stateManager.status == .paused)

    // Resume
    stateManager.togglePause()
    #expect(stateManager.status == .active)
  }

  @Test func repeatedStartDoesNotResetActiveCountdown() {
    let defaults = UserDefaults.standard
    let previousWork = defaults.object(forKey: SettingKey.workDuration)
    let previousReset = defaults.object(forKey: SettingKey.forceResetFocusAfterBreak)
    defer {
      restoreDefault(previousWork, key: SettingKey.workDuration)
      restoreDefault(previousReset, key: SettingKey.forceResetFocusAfterBreak)
    }
    defaults.set(8.0, forKey: SettingKey.workDuration)
    defaults.set(false, forKey: SettingKey.forceResetFocusAfterBreak)

    let stateManager = StateManager()  // init reads workDuration=8 → timeRemaining=8
    stateManager.focusScheduleEnabled = false

    Thread.sleep(forTimeInterval: 1.1)
    stateManager.start()
    Thread.sleep(forTimeInterval: 1.1)
    stateManager.transition(to: .onBreak)
    stateManager.transition(to: .active)

    #expect(stateManager.status == .active)
    #expect(stateManager.timeRemaining < 7)
    #expect(stateManager.timeRemaining > 4)
  }

  @Test func overlappingWellnessDoesNotEraseSavedFocusProgress() {
    let defaults = UserDefaults.standard
    let previousWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(previousWork, key: SettingKey.workDuration) }
    defaults.set(300.0, forKey: SettingKey.workDuration)

    let stateManager = StateManager()  // init reads workDuration=300 → timeRemaining=300
    stateManager.focusScheduleEnabled = false
    let baseline = stateManager.timeRemaining  // ≈ 300

    stateManager.transition(to: .wellness(type: .posture))
    Thread.sleep(forTimeInterval: 0.2)
    stateManager.transition(to: .wellness(type: .blink))
    stateManager.transition(to: .active)

    #expect(stateManager.timeRemaining > 60)
    #expect(stateManager.timeRemaining > baseline - 3)
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

  @Test func schedulePolicyHandlesDayWindowAndWeekdays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = isoDate("2026-02-25T14:00:00Z")  // Wednesday

    let inside = SchedulePolicy.isWithinActiveSchedule(
      now: now,
      enabled: true,
      startMinute: 9 * 60,
      endMinute: 18 * 60,
      weekdaysCSV: "2,3,4,5,6",
      calendar: calendar
    )
    #expect(inside == true)

    let sunday = isoDate("2026-02-22T14:00:00Z")
    let outsideWeekday = SchedulePolicy.isWithinActiveSchedule(
      now: sunday,
      enabled: true,
      startMinute: 9 * 60,
      endMinute: 18 * 60,
      weekdaysCSV: "2,3,4,5,6",
      calendar: calendar
    )
    #expect(outsideWeekday == false)
  }

  @Test func schedulePolicyHandlesOvernightQuietHours() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let night = isoDate("2026-02-25T23:30:00Z")
    let morning = isoDate("2026-02-26T06:30:00Z")
    let daytime = isoDate("2026-02-26T11:30:00Z")

    #expect(
      SchedulePolicy.isWithinQuietHours(
        now: night,
        enabled: true,
        startMinute: 22 * 60,
        endMinute: 7 * 60,
        calendar: calendar
      ) == true)
    #expect(
      SchedulePolicy.isWithinQuietHours(
        now: morning,
        enabled: true,
        startMinute: 22 * 60,
        endMinute: 7 * 60,
        calendar: calendar
      ) == true)
    #expect(
      SchedulePolicy.isWithinQuietHours(
        now: daytime,
        enabled: true,
        startMinute: 22 * 60,
        endMinute: 7 * 60,
        calendar: calendar
      ) == false)
  }

  @Test func breakResumePolicyHonorsAdvancedPreference() throws {
    let defaults = UserDefaults.standard
    let previousWork = defaults.object(forKey: SettingKey.workDuration)
    let previousReset = defaults.object(forKey: SettingKey.forceResetFocusAfterBreak)
    defer {
      restoreDefault(previousWork, key: SettingKey.workDuration)
      restoreDefault(previousReset, key: SettingKey.forceResetFocusAfterBreak)
    }
    defaults.set(4.0, forKey: SettingKey.workDuration)
    defaults.set(false, forKey: SettingKey.forceResetFocusAfterBreak)

    let stateManager = StateManager()  // init reads workDuration=4 → timeRemaining=4
    Thread.sleep(forTimeInterval: 1.2)
    stateManager.transition(to: .onBreak)
    stateManager.transition(to: .active)
    #expect(stateManager.timeRemaining < 3.4)
    #expect(stateManager.timeRemaining > 2.1)
  }

  @Test func wellnessDurationMultiplierScalesOverlayDuration() throws {
    let defaults = UserDefaults.standard
    let previousMultiplier = defaults.object(forKey: SettingKey.wellnessDurationMultiplier)
    defer { restoreDefault(previousMultiplier, key: SettingKey.wellnessDurationMultiplier) }

    defaults.set(2.0, forKey: SettingKey.wellnessDurationMultiplier)
    let stateManager = StateManager()
    stateManager.transition(to: .wellness(type: .posture))
    #expect(abs(stateManager.timeRemaining - 1.5) < 0.2)  // posture 0.75s × 2.0 multiplier
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

  // MARK: - SchedulePolicy Additional Tests

  @Test func schedulePolicyDisabledAlwaysReturnsTrue() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let sunday = isoDate("2026-02-22T22:00:00Z")
    let result = SchedulePolicy.isWithinActiveSchedule(
      now: sunday, enabled: false,
      startMinute: 9 * 60, endMinute: 18 * 60,
      weekdaysCSV: "2,3,4,5,6", calendar: calendar
    )
    #expect(result == true)
  }

  @Test func quietHoursDisabledAlwaysReturnsFalse() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let midnight = isoDate("2026-02-25T23:00:00Z")
    let result = SchedulePolicy.isWithinQuietHours(
      now: midnight, enabled: false,
      startMinute: 22 * 60, endMinute: 7 * 60,
      calendar: calendar
    )
    #expect(result == false)
  }

  @Test func weekdaySetParsingFromCSV() {
    let monToFri = SchedulePolicy.weekdaySet(from: "2,3,4,5,6")
    #expect(monToFri == Set([2, 3, 4, 5, 6]))

    let weekends = SchedulePolicy.weekdaySet(from: "1,7")
    #expect(weekends == Set([1, 7]))

    let single = SchedulePolicy.weekdaySet(from: "4")
    #expect(single == Set([4]))

    #expect(SchedulePolicy.weekdaySet(from: "").isEmpty)
  }

  @Test func weekdayCSVRoundTrip() {
    let original = Set([2, 3, 4, 5, 6])
    let csv = SchedulePolicy.weekdayCSV(from: original)
    #expect(SchedulePolicy.weekdaySet(from: csv) == original)

    let allDays = Set([1, 2, 3, 4, 5, 6, 7])
    let csv2 = SchedulePolicy.weekdayCSV(from: allDays)
    #expect(SchedulePolicy.weekdaySet(from: csv2) == allDays)
  }

  @Test func scheduleWindowIncludesExactStartMinute() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    // Wednesday 09:00 UTC = minuteOfDay 540 — should be INCLUDED (>= start)
    let atStart = isoDate("2026-02-25T09:00:00Z")
    #expect(
      SchedulePolicy.isWithinActiveSchedule(
        now: atStart, enabled: true,
        startMinute: 9 * 60, endMinute: 18 * 60,
        weekdaysCSV: "2,3,4,5,6", calendar: calendar
      ) == true
    )
  }

  @Test func scheduleWindowExcludesExactEndMinute() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    // Wednesday 18:00 UTC = minuteOfDay 1080 — should be EXCLUDED (< end)
    let atEnd = isoDate("2026-02-25T18:00:00Z")
    #expect(
      SchedulePolicy.isWithinActiveSchedule(
        now: atEnd, enabled: true,
        startMinute: 9 * 60, endMinute: 18 * 60,
        weekdaysCSV: "2,3,4,5,6", calendar: calendar
      ) == false
    )
  }

  @Test func scheduleWindowStartEqualsEndReturnsTrue() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let wednesday = isoDate("2026-02-25T14:00:00Z")
    #expect(
      SchedulePolicy.isWithinActiveSchedule(
        now: wednesday, enabled: true,
        startMinute: 9 * 60, endMinute: 9 * 60,
        weekdaysCSV: "2,3,4,5,6", calendar: calendar
      ) == true
    )
  }

  @Test func scheduleWindowSaturdayExcluded() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    // 2026-02-28 is Saturday (weekday = 7)
    let saturday = isoDate("2026-02-28T14:00:00Z")
    #expect(
      SchedulePolicy.isWithinActiveSchedule(
        now: saturday, enabled: true,
        startMinute: 9 * 60, endMinute: 18 * 60,
        weekdaysCSV: "2,3,4,5,6", calendar: calendar
      ) == false
    )
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

  // MARK: - StateManager: canSkip / skipLock

  @Test func hardcoreModeCannotSkip() {
    let sm = StateManager()
    sm.breakDuration = 60
    sm.difficultyRaw = BreakDifficulty.hardcore.rawValue
    sm.transition(to: .onBreak)
    #expect(sm.canSkip == false)
    #expect(sm.difficulty == .hardcore)
  }

  @Test func casualModeCanAlwaysSkip() {
    let sm = StateManager()
    sm.breakDuration = 60
    sm.difficultyRaw = BreakDifficulty.casual.rawValue
    sm.transition(to: .onBreak)
    #expect(sm.canSkip == true)
  }

  @Test func balancedModeLockedAtBreakStart() {
    let sm = StateManager()
    sm.breakDuration = 300
    sm.balancedSkipLockRatio = 0.5  // skipLock = min(20, 150) = 20
    sm.difficultyRaw = BreakDifficulty.balanced.rawValue
    sm.transition(to: .onBreak)
    // timeRemaining = 300, threshold = 300 - 20 = 280 → 300 > 280 → cannot skip
    #expect(sm.canSkip == false)
  }

  @Test func skipLockDurationCappedAt20Seconds() {
    let sm = StateManager()
    sm.breakDuration = 300
    sm.balancedSkipLockRatio = 0.8  // 80% of 300 = 240, capped at 20
    sm.difficultyRaw = BreakDifficulty.balanced.rawValue
    sm.transition(to: .onBreak)
    // skipLock = min(20, 240) = 20 → skipSecondsRemaining = ceil(300 - (300-20)) = 20
    #expect(sm.skipSecondsRemaining == 20)
    #expect(sm.canSkip == false)
  }

  @Test func skipSecondsRemainingDecreasesAsTimePassesOnBreak() {
    let sm = StateManager()
    sm.breakDuration = 60
    sm.balancedSkipLockRatio = 0.5  // skipLock = min(20, 30) = 20
    sm.difficultyRaw = BreakDifficulty.balanced.rawValue
    sm.transition(to: .onBreak)
    // threshold = 60 - 20 = 40; skipSecondsRemaining = ceil(60 - 40) = 20
    #expect(sm.skipSecondsRemaining == 20)
    sm.timeRemaining = 50
    #expect(sm.skipSecondsRemaining == 10)
    sm.timeRemaining = 40
    #expect(sm.skipSecondsRemaining == 0)
    #expect(sm.canSkip == true)
  }

  // MARK: - StateManager: snoozeNudge and extendBreak

  @Test func snoozeNudgeExtendsTimerAndBecomesActive() {
    let sm = StateManager()
    sm.workDuration = 30
    sm.nudgeLeadTime = 10
    sm.transition(to: .nudge)
    #expect(sm.status == .nudge)

    let before = sm.timeRemaining
    sm.snoozeNudge(by: 300)

    #expect(sm.status == .active)
    #expect(sm.timeRemaining >= before + 299)
  }

  @Test func snoozeNudgeIsNoOpWhenNotInNudge() {
    let sm = StateManager()
    sm.workDuration = 300
    let before = sm.timeRemaining
    sm.snoozeNudge(by: 300)
    #expect(sm.status == .active)
    #expect(abs(sm.timeRemaining - before) < 1.0)
  }

  @Test func extendBreakAddsTimeToBreak() {
    let sm = StateManager()
    sm.breakDuration = 60
    sm.transition(to: .onBreak)
    #expect(sm.status == .onBreak)

    let before = sm.timeRemaining
    sm.extendBreak(by: 30)

    #expect(sm.status == .onBreak)
    #expect(sm.timeRemaining >= before + 29)
  }

  @Test func extendBreakIsNoOpWhenNotOnBreak() {
    let sm = StateManager()
    #expect(sm.status == .active)
    let before = sm.timeRemaining
    sm.extendBreak(by: 30)
    #expect(sm.status == .active)
    #expect(abs(sm.timeRemaining - before) < 1.0)
  }

  // MARK: - StateManager: Pause/Resume Fixes (2026-06-29)

  @Test func pauseFromBreakRestoresBreakOnResume() {
    let sm = StateManager()
    sm.breakDuration = 60
    sm.transition(to: .onBreak)
    #expect(sm.status == .onBreak)

    sm.togglePause()
    #expect(sm.status == .paused)

    sm.togglePause()
    // Fix: must restore to .onBreak, not .active
    #expect(sm.status == .onBreak)
  }

  @Test func pauseFromActiveRestoresActiveOnResume() {
    let sm = StateManager()
    #expect(sm.status == .active)
    sm.togglePause()
    #expect(sm.status == .paused)
    sm.togglePause()
    #expect(sm.status == .active)
  }

  @Test func pauseTimeRemainingIsPreservedAcrossToggle() {
    let sm = StateManager()
    let before = sm.timeRemaining
    sm.togglePause()
    let during = sm.timeRemaining
    sm.togglePause()
    #expect(sm.timeRemaining >= 1)
    #expect(sm.timeRemaining <= before)
    #expect(abs(sm.timeRemaining - during) < 2.0)
  }

  // MARK: - StateManager: continuousFocusTime

  @Test func continuousFocusTimeResetsAfterBreakCompletes() {
    let sm = StateManager()
    sm.continuousFocusTime = 500
    sm.transition(to: .onBreak)
    sm.transition(to: .active)
    #expect(sm.continuousFocusTime == 0)
  }

  @Test func continuousFocusTimeResetsWhenSkippingFromNudge() {
    let sm = StateManager()
    sm.continuousFocusTime = 300
    sm.transition(to: .nudge)
    sm.transition(to: .active)
    #expect(sm.continuousFocusTime == 0)
  }

  // MARK: - StateManager: Real-time duration update (mid-session settings change)

  @Test func increasingWorkDurationMidSessionExtendsActiveDeadline() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }
    defaults.set(300.0, forKey: SettingKey.workDuration)

    let sm = StateManager()  // starts with timeRemaining ≈ 300
    sm.focusScheduleEnabled = false
    let before = sm.timeRemaining

    // Simulate settings change: user bumps work duration from 5m → 25m (+1200s)
    defaults.set(1500.0, forKey: SettingKey.workDuration)
    // Trigger a heartbeat tick to pick up the new value
    sm.refreshSettingsForTesting()

    // timeRemaining should have increased by the delta
    #expect(sm.timeRemaining > before + 1100)
  }

  @Test func decreasingWorkDurationMidSessionShortenssActiveDeadline() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }
    defaults.set(1500.0, forKey: SettingKey.workDuration)

    let sm = StateManager()  // starts with timeRemaining ≈ 1500
    sm.focusScheduleEnabled = false
    let before = sm.timeRemaining

    // User drops work duration from 25m → 5m (-1200s)
    defaults.set(300.0, forKey: SettingKey.workDuration)
    sm.refreshSettingsForTesting()

    #expect(sm.timeRemaining < before - 1100)
  }

  @Test func breakDurationChangeMidBreakUpdatesBreakCountdown() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    defer {
      restoreDefault(prevWork, key: SettingKey.workDuration)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
    }
    defaults.set(300.0, forKey: SettingKey.workDuration)
    defaults.set(60.0, forKey: SettingKey.breakDuration)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.transition(to: .onBreak)
    let before = sm.timeRemaining  // ≈ 60

    // User extends break from 1m → 5m mid-break
    defaults.set(300.0, forKey: SettingKey.breakDuration)
    sm.refreshSettingsForTesting()

    #expect(sm.timeRemaining > before + 100)
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

  @Test func pauseFromWellnessResumesFocusTimerNotWellnessTimer() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }
    defaults.set(500.0, forKey: SettingKey.workDuration)

    let sm = StateManager()
    sm.focusScheduleEnabled = false

    // Enter wellness — savedWorkTimeRemaining should capture the focus time
    sm.transition(to: .wellness(type: .posture))
    #expect(sm.status == .wellness(type: .posture))

    // Pause mid-wellness (timeRemaining is the tiny wellness duration ~0.75s)
    sm.togglePause()
    #expect(sm.status == .paused)

    // Resume — should restore the 500s work timer, not the 0.75s wellness timer
    sm.togglePause()
    #expect(sm.status == .active)
    #expect(sm.timeRemaining > 60, "Expected focus timer restored, got \(sm.timeRemaining)s")
  }

  @Test func registerDefaultsDoesNotOverrideExistingUserValues() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }

    defaults.set(9999.0, forKey: SettingKey.workDuration)
    SettingKey.registerDefaults()  // must NOT overwrite the 9999

    #expect(defaults.double(forKey: SettingKey.workDuration) == 9999.0)
  }

  @Test func skipLockRatioFloorClampPreventsTooEarlySkip() {
    let defaults = UserDefaults.standard
    let prevRatio = defaults.object(forKey: SettingKey.balancedSkipLockRatio)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    defer {
      restoreDefault(prevRatio, key: SettingKey.balancedSkipLockRatio)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
      restoreDefault(prevDiff, key: SettingKey.difficulty)
    }
    // ratio = 0.05 → clamped to 0.1 → skipLock = min(20, 100*0.1) = 10s
    // canSkip = true only when timeRemaining <= 100 - 10 = 90
    defaults.set(0.05, forKey: SettingKey.balancedSkipLockRatio)
    defaults.set(100.0, forKey: SettingKey.breakDuration)
    defaults.set(BreakDifficulty.balanced.rawValue, forKey: SettingKey.difficulty)

    let sm = StateManager()
    sm.transition(to: .onBreak)
    sm.timeRemaining = 91  // above the threshold of 90
    #expect(!sm.canSkip, "canSkip should be false at 91s (skipLock threshold is 90s)")
    sm.timeRemaining = 89  // below the threshold
    #expect(sm.canSkip, "canSkip should be true at 89s (skipLock threshold is 90s)")
  }

  @Test func skipLockCapMakesLongBreakSkippableAfterOnlyTwentySeconds() {
    let defaults = UserDefaults.standard
    let prevRatio = defaults.object(forKey: SettingKey.balancedSkipLockRatio)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    defer {
      restoreDefault(prevRatio, key: SettingKey.balancedSkipLockRatio)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
      restoreDefault(prevDiff, key: SettingKey.difficulty)
    }
    // ratio = 0.5, breakDuration = 120s → uncapped lock = 60s; capped = 20s
    // with cap: canSkip when timeRemaining <= 120 - 20 = 100
    defaults.set(0.5, forKey: SettingKey.balancedSkipLockRatio)
    defaults.set(120.0, forKey: SettingKey.breakDuration)
    defaults.set(BreakDifficulty.balanced.rawValue, forKey: SettingKey.difficulty)

    let sm = StateManager()
    sm.transition(to: .onBreak)
    sm.timeRemaining = 75  // 75 <= 100 → should be skippable (cap=20, not uncapped 60)
    #expect(sm.canSkip, "canSkip should be true at 75s when cap=20s (threshold=100s)")
  }

  @Test func casualDifficultyCanSkipAlwaysTrue() {
    let defaults = UserDefaults.standard
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    defer {
      restoreDefault(prevDiff, key: SettingKey.difficulty)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
    }
    defaults.set(BreakDifficulty.casual.rawValue, forKey: SettingKey.difficulty)
    defaults.set(300.0, forKey: SettingKey.breakDuration)

    let sm = StateManager()
    sm.transition(to: .onBreak)

    sm.timeRemaining = 300  // break just started
    #expect(sm.canSkip, "Casual should always allow skipping")
    sm.timeRemaining = 150  // halfway
    #expect(sm.canSkip)
    sm.timeRemaining = 1  // nearly done
    #expect(sm.canSkip)
  }

  @Test func hardcoreDifficultyCanSkipAlwaysFalse() {
    let defaults = UserDefaults.standard
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    defer {
      restoreDefault(prevDiff, key: SettingKey.difficulty)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
    }
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    defaults.set(300.0, forKey: SettingKey.breakDuration)

    let sm = StateManager()
    sm.transition(to: .onBreak)

    sm.timeRemaining = 300
    #expect(!sm.canSkip, "Hardcore should never allow skipping")
    sm.timeRemaining = 1
    #expect(!sm.canSkip)
  }

  @Test func showTypingIndicatorOnlyTrueDuringNudge() {
    let sm = StateManager()
    sm.focusScheduleEnabled = false

    // In .active: never shows typing indicator
    sm.isTyping = true
    #expect(!sm.showTypingIndicator, "Typing indicator only shows during .nudge")

    // In .nudge with typing: shows
    sm.transition(to: .nudge)
    sm.isTyping = true
    #expect(sm.showTypingIndicator)

    // In .nudge without typing: doesn't show
    sm.isTyping = false
    #expect(!sm.showTypingIndicator)

    // In .onBreak: never shows
    sm.transition(to: .onBreak)
    sm.isTyping = true
    #expect(!sm.showTypingIndicator)
  }

  @Test func dayProgressDisabledReturnsAllZeros() {
    let defaults = UserDefaults.standard
    let prevEnabled = defaults.object(forKey: SettingKey.dayProgressEnabled)
    defer { restoreDefault(prevEnabled, key: SettingKey.dayProgressEnabled) }
    defaults.set(false, forKey: SettingKey.dayProgressEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    // Simulate one heartbeat's worth of updateDayProgress via refreshSettings
    sm.refreshSettingsForTesting()

    #expect(sm.dayProgressPercent == 0)
    #expect(sm.dayProgressTimeRemaining == 0)
    #expect(sm.dayProgressTimeElapsed == 0)
  }

  @Test func isScheduleSleepingSetOnlyByScheduleEnforcementNotManualPause() {
    let sm = StateManager()
    sm.focusScheduleEnabled = false
    #expect(!sm.isScheduleSleeping)

    // Manual pause must NOT set isScheduleSleeping
    sm.togglePause()
    #expect(sm.status == .paused)
    #expect(!sm.isScheduleSleeping, "Manual pause should not set isScheduleSleeping")

    sm.togglePause()
    #expect(!sm.isScheduleSleeping)
  }

  @Test func wellnessDurationMultiplierAppliesOnNextTransition() {
    let defaults = UserDefaults.standard
    let prevMult = defaults.object(forKey: SettingKey.wellnessDurationMultiplier)
    defer { restoreDefault(prevMult, key: SettingKey.wellnessDurationMultiplier) }

    defaults.set(2.0, forKey: SettingKey.wellnessDurationMultiplier)
    let sm = StateManager()
    sm.focusScheduleEnabled = false

    sm.transition(to: .wellness(type: .posture))
    // posture base duration = 0.75s × 2.0 multiplier = 1.5s
    #expect(abs(sm.timeRemaining - 1.5) < 0.1, "Expected 1.5s, got \(sm.timeRemaining)s")
  }

  @Test func breakTransitionToActiveProperlyClearsContinuousFocusTime() {
    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.continuousFocusTime = 500

    sm.transition(to: .onBreak)
    sm.transition(to: .active)
    #expect(sm.continuousFocusTime == 0, "continuousFocusTime must reset when exiting a break")
  }

  @Test func continuousFocusTimeResetsOnBreakAndSkip() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }
    defaults.set(20.0, forKey: SettingKey.workDuration)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.continuousFocusTime = 999  // pretend we focused for a while

    // Skipping a break (nudge → active) resets continuousFocusTime
    sm.transition(to: .nudge)
    sm.transition(to: .active)
    #expect(sm.continuousFocusTime == 0, "Skip from nudge should reset continuousFocusTime")

    sm.continuousFocusTime = 888
    sm.transition(to: .onBreak)
    sm.transition(to: .active)
    #expect(sm.continuousFocusTime == 0, "Completing a break should reset continuousFocusTime")
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

  // MARK: - StateManager: Focus schedule enforcement (sleep / auto-resume)

  @Test func scheduleSleepsWhenOutsideActiveWindow() {
    let defaults = UserDefaults.standard
    let keys = [
      SettingKey.focusScheduleEnabled, SettingKey.focusScheduleStartMinute,
      SettingKey.focusScheduleEndMinute, SettingKey.focusScheduleWeekdays,
      SettingKey.focusScheduleAutoResume,
    ]
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    let sm = StateManager()
    sm.focusScheduleEnabled = true
    sm.focusScheduleStartMinute = 540  // 09:00
    sm.focusScheduleEndMinute = 1080  // 18:00
    sm.focusScheduleWeekdays = "2,3,4,5,6"  // Mon–Fri
    sm.focusScheduleAutoResume = true
    #expect(sm.status == .active)

    // Monday 20:00 is outside the 09:00–18:00 window → should sleep.
    let changed = sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 20, minute: 0))
    #expect(changed)
    #expect(sm.status == .paused)
    #expect(sm.isScheduleSleeping)
  }

  @Test func scheduleAutoResumesWhenBackInWindow() {
    let defaults = UserDefaults.standard
    let keys = [
      SettingKey.focusScheduleEnabled, SettingKey.focusScheduleStartMinute,
      SettingKey.focusScheduleEndMinute, SettingKey.focusScheduleWeekdays,
      SettingKey.focusScheduleAutoResume,
    ]
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    let sm = StateManager()
    sm.focusScheduleEnabled = true
    sm.focusScheduleStartMinute = 540
    sm.focusScheduleEndMinute = 1080
    sm.focusScheduleWeekdays = "2,3,4,5,6"
    sm.focusScheduleAutoResume = true

    // Sleep first (Monday 20:00), then re-evaluate inside the window (Monday 12:00).
    sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 20, minute: 0))
    #expect(sm.status == .paused)

    let resumed = sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 12, minute: 0))
    #expect(resumed)
    #expect(sm.status == .active)
    #expect(!sm.isScheduleSleeping)
  }

  @Test func scheduleDoesNotAutoResumeWhenAutoResumeDisabled() {
    let defaults = UserDefaults.standard
    let keys = [
      SettingKey.focusScheduleEnabled, SettingKey.focusScheduleStartMinute,
      SettingKey.focusScheduleEndMinute, SettingKey.focusScheduleWeekdays,
      SettingKey.focusScheduleAutoResume,
    ]
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    let sm = StateManager()
    sm.focusScheduleEnabled = true
    sm.focusScheduleStartMinute = 540
    sm.focusScheduleEndMinute = 1080
    sm.focusScheduleWeekdays = "2,3,4,5,6"
    sm.focusScheduleAutoResume = true

    sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 20, minute: 0))
    #expect(sm.status == .paused)

    // With auto-resume off, returning to the window must NOT wake the app.
    sm.focusScheduleAutoResume = false
    let changed = sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 12, minute: 0))
    #expect(!changed)
    #expect(sm.status == .paused, "Schedule must stay asleep when auto-resume is disabled")
  }

  // MARK: - StateManager: Day progress math

  @Test func dayProgressEnabledProducesValidRange() {
    let defaults = UserDefaults.standard
    let prevEnabled = defaults.object(forKey: SettingKey.dayProgressEnabled)
    let prevStart = defaults.object(forKey: SettingKey.dayProgressStartMinute)
    let prevEnd = defaults.object(forKey: SettingKey.dayProgressEndMinute)
    defer {
      restoreDefault(prevEnabled, key: SettingKey.dayProgressEnabled)
      restoreDefault(prevStart, key: SettingKey.dayProgressStartMinute)
      restoreDefault(prevEnd, key: SettingKey.dayProgressEndMinute)
    }

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.dayProgressEnabled = true
    sm.dayProgressStartMinute = 0  // 00:00
    sm.dayProgressEndMinute = 1439  // 23:59
    sm.updateDayProgressForTesting()

    #expect(sm.dayProgressPercent >= 0 && sm.dayProgressPercent <= 1)
    #expect(sm.dayProgressTimeElapsed >= 0)
    #expect(sm.dayProgressTimeRemaining >= 0)
  }

  @Test func dayProgressInvertedWindowReturnsZeros() {
    let defaults = UserDefaults.standard
    let prevEnabled = defaults.object(forKey: SettingKey.dayProgressEnabled)
    let prevStart = defaults.object(forKey: SettingKey.dayProgressStartMinute)
    let prevEnd = defaults.object(forKey: SettingKey.dayProgressEndMinute)
    defer {
      restoreDefault(prevEnabled, key: SettingKey.dayProgressEnabled)
      restoreDefault(prevStart, key: SettingKey.dayProgressStartMinute)
      restoreDefault(prevEnd, key: SettingKey.dayProgressEndMinute)
    }

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.dayProgressEnabled = true
    // end (09:00) is before start (18:00) → guard fails → all zeros.
    // Documents the current limitation: day-progress windows must not wrap past midnight.
    sm.dayProgressStartMinute = 1080  // 18:00
    sm.dayProgressEndMinute = 540  // 09:00
    sm.updateDayProgressForTesting()

    #expect(sm.dayProgressPercent == 0)
    #expect(sm.dayProgressTimeRemaining == 0)
    #expect(sm.dayProgressTimeElapsed == 0)
  }

  // MARK: - Wellness system: enabled flags, quiet hours, firing order (2026-06-30)

  /// Helper: configures UserDefaults so only one wellness type is active, returns cleanup keys.
  private func wellnessOnlyKeys() -> [String] {
    [
      SettingKey.postureEnabled, SettingKey.postureFrequency,
      SettingKey.blinkEnabled, SettingKey.blinkFrequency,
      SettingKey.waterEnabled, SettingKey.waterFrequency,
      SettingKey.affirmationEnabled, SettingKey.affirmationFrequency,
      SettingKey.quietHoursEnabled, SettingKey.quietHoursStartMinute,
      SettingKey.quietHoursEndMinute,
    ]
  }

  @Test func wellnessFiresWhenEnabledAndDue() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(60.0, forKey: SettingKey.postureFrequency)
    defaults.set(false, forKey: SettingKey.blinkEnabled)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    // First call: seeds nextPostureDue = t + 60s, does NOT fire
    sm.checkWellnessRemindersForTesting(now: t)
    #expect(sm.status == .active)

    // 61s later: past due, must fire
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(61))
    #expect(sm.status == .wellness(type: .posture), "Posture must fire when enabled and past due")
  }

  @Test func postureEnabledFalseBlocksWellnessFiring() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(60.0, forKey: SettingKey.postureFrequency)
    defaults.set(false, forKey: SettingKey.blinkEnabled)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    // Seed the due date while posture is enabled
    sm.checkWellnessRemindersForTesting(now: t)

    // Disable posture
    defaults.set(false, forKey: SettingKey.postureEnabled)

    // Past due — but disabled, must NOT fire
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(61))
    #expect(sm.status == .active, "Disabled posture must not fire even when past due date")
  }

  @Test func quietHoursPreventWellnessFiring() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(60.0, forKey: SettingKey.postureFrequency)
    defaults.set(false, forKey: SettingKey.blinkEnabled)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    // Seed due date with quiet hours OFF
    sm.checkWellnessRemindersForTesting(now: t)

    // Enable always-on quiet hours (start == end → always active per SchedulePolicy)
    sm.quietHoursEnabled = true
    sm.quietHoursStartMinute = 0
    sm.quietHoursEndMinute = 0

    // Past due — but quiet hours active, must NOT fire
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(61))
    #expect(sm.status == .active, "Quiet hours must prevent wellness from firing when due")
  }

  @Test func wellnessFiringOrderIsPostureBeforeBlink() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(60.0, forKey: SettingKey.postureFrequency)
    defaults.set(true, forKey: SettingKey.blinkEnabled)
    defaults.set(60.0, forKey: SettingKey.blinkFrequency)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    sm.checkWellnessRemindersForTesting(now: t)  // seeds both due at t+60

    // Both past due — posture is checked first in checkWellnessReminders
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(61))
    #expect(sm.status == .wellness(type: .posture), "Posture fires before blink when both are due")
  }

  @Test func postureReEnabledAfterDisableStartsFreshTimer() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(60.0, forKey: SettingKey.postureFrequency)
    defaults.set(false, forKey: SettingKey.blinkEnabled)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    // Seed: nextPostureDue = t + 60s
    sm.checkWellnessRemindersForTesting(now: t)

    // Disable at t+10 → nils nextPostureDue
    defaults.set(false, forKey: SettingKey.postureEnabled)
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(10))

    // Re-enable at t+15 → nextPostureDue = t+15+60 = t+75
    defaults.set(true, forKey: SettingKey.postureEnabled)
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(15))
    #expect(
      sm.status == .active, "Re-enabling posture should start fresh timer, not fire immediately")

    // Original t+61: nextPostureDue is now t+75, must NOT fire yet
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(61))
    #expect(sm.status == .active, "Must not fire at old due date after re-enable reset")

    // t+76: past the new t+75 due date → fires
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(76))
    #expect(sm.status == .wellness(type: .posture), "Posture must fire 60s after re-enable")
  }

  // MARK: - Settings propagation: runtime changes via refreshSettings (2026-06-30)

  @Test func wellnessFrequencyChangeViaRefreshSettingsReschedulesTimer() {
    let defaults = UserDefaults.standard
    let keys = wellnessOnlyKeys()
    let prev = keys.map { defaults.object(forKey: $0) }
    defer { for (i, k) in keys.enumerated() { restoreDefault(prev[i], key: k) } }

    defaults.set(true, forKey: SettingKey.postureEnabled)
    defaults.set(120.0, forKey: SettingKey.postureFrequency)
    defaults.set(false, forKey: SettingKey.blinkEnabled)
    defaults.set(false, forKey: SettingKey.waterEnabled)
    defaults.set(false, forKey: SettingKey.affirmationEnabled)
    defaults.set(false, forKey: SettingKey.quietHoursEnabled)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    let t = Date()

    // Seed: nextPostureDue = t + 120s
    sm.checkWellnessRemindersForTesting(now: t)

    // Shorten frequency to 50s → refreshSettings reschedules nextPostureDue ≈ now + 50s
    defaults.set(50.0, forKey: SettingKey.postureFrequency)
    sm.refreshSettingsForTesting()

    // At t+55: should fire under the new 50s schedule (not the original 120s one)
    sm.checkWellnessRemindersForTesting(now: t.addingTimeInterval(55))
    #expect(
      sm.status == .wellness(type: .posture),
      "After frequency shortened to 50s, posture must fire at 55s (not wait until t+120)")
  }

  @Test func difficultyChangeViaRefreshSettingsUpdatesCanSkip() {
    let defaults = UserDefaults.standard
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    defer {
      restoreDefault(prevDiff, key: SettingKey.difficulty)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
    }
    defaults.set(BreakDifficulty.balanced.rawValue, forKey: SettingKey.difficulty)
    defaults.set(300.0, forKey: SettingKey.breakDuration)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.transition(to: .onBreak)

    // At break start (timeRemaining=300), balanced skipLock=20 → threshold=280 → locked
    #expect(!sm.canSkip, "Balanced at break start should not allow skip")

    // Flip to casual via UserDefaults + refreshSettings
    defaults.set(BreakDifficulty.casual.rawValue, forKey: SettingKey.difficulty)
    sm.refreshSettingsForTesting()

    #expect(sm.difficulty == .casual)
    #expect(sm.canSkip, "After switching to casual, canSkip must be true immediately")
  }

  @Test func skipLockRatioChangeViaRefreshSettingsAffectsThreshold() {
    let defaults = UserDefaults.standard
    let prevRatio = defaults.object(forKey: SettingKey.balancedSkipLockRatio)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    let prevDiff = defaults.object(forKey: SettingKey.difficulty)
    defer {
      restoreDefault(prevRatio, key: SettingKey.balancedSkipLockRatio)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
      restoreDefault(prevDiff, key: SettingKey.difficulty)
    }
    // ratio=0.1 → skipLock = min(20, 100×0.1) = 10s → canSkip threshold = 90s
    defaults.set(0.1, forKey: SettingKey.balancedSkipLockRatio)
    defaults.set(100.0, forKey: SettingKey.breakDuration)
    defaults.set(BreakDifficulty.balanced.rawValue, forKey: SettingKey.difficulty)

    let sm = StateManager()
    sm.focusScheduleEnabled = false
    sm.transition(to: .onBreak)

    sm.timeRemaining = 85  // 85 ≤ 90 → canSkip = true
    #expect(sm.canSkip, "With ratio=0.1, canSkip must be true at 85s (threshold=90s)")

    // Change ratio to 0.2 → skipLock = min(20, 20) = 20s → threshold = 80s
    defaults.set(0.2, forKey: SettingKey.balancedSkipLockRatio)
    sm.refreshSettingsForTesting()

    // timeRemaining is still 85 > 80 → canSkip = false
    #expect(!sm.canSkip, "After ratio=0.2, canSkip must be false at 85s (threshold now 80s)")
  }

  @Test func wellnessDurationMultiplierChangeViaRefreshSettingsAppliesNextTransition() {
    let defaults = UserDefaults.standard
    let prevMult = defaults.object(forKey: SettingKey.wellnessDurationMultiplier)
    defer { restoreDefault(prevMult, key: SettingKey.wellnessDurationMultiplier) }

    defaults.set(1.0, forKey: SettingKey.wellnessDurationMultiplier)
    let sm = StateManager()
    sm.focusScheduleEnabled = false

    sm.transition(to: .wellness(type: .posture))
    #expect(abs(sm.timeRemaining - 0.75) < 0.1, "Posture with multiplier=1.0 must last ~0.75s")
    sm.transition(to: .active)

    // Drop multiplier to 0.25×
    defaults.set(0.25, forKey: SettingKey.wellnessDurationMultiplier)
    sm.refreshSettingsForTesting()

    sm.transition(to: .wellness(type: .posture))
    // 0.75 × 0.25 = 0.1875s — clamped to max(0.1, 0.1875) = 0.1875
    #expect(sm.timeRemaining < 0.5, "With multiplier=0.25×, posture duration must be under 0.5s")
    #expect(sm.timeRemaining > 0.05, "Posture duration must remain positive")
    sm.transition(to: .active)
  }

  @Test func nudgeLeadTimeChangeViaRefreshSettingsUpdatesProperty() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.nudgeLeadTime)
    defer { restoreDefault(prev, key: SettingKey.nudgeLeadTime) }

    defaults.set(10.0, forKey: SettingKey.nudgeLeadTime)
    let sm = StateManager()
    sm.focusScheduleEnabled = false
    #expect(sm.nudgeLeadTime == 10.0)

    defaults.set(60.0, forKey: SettingKey.nudgeLeadTime)
    sm.refreshSettingsForTesting()
    #expect(sm.nudgeLeadTime == 60.0, "nudgeLeadTime must update via refreshSettings")
  }

  @Test func idleThresholdChangeViaRefreshSettingsUpdatesProperty() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.focusIdleThreshold)
    defer { restoreDefault(prev, key: SettingKey.focusIdleThreshold) }

    defaults.set(20.0, forKey: SettingKey.focusIdleThreshold)
    let sm = StateManager()
    sm.focusScheduleEnabled = false
    #expect(sm.idleThreshold == 20.0)

    defaults.set(45.0, forKey: SettingKey.focusIdleThreshold)
    sm.refreshSettingsForTesting()
    #expect(sm.idleThreshold == 45.0, "idleThreshold must update via refreshSettings")
  }

  @Test func forceResetFocusAfterBreakFalseViaRefreshSettingsAppliesAtBreakEnd() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    let prevBreak = defaults.object(forKey: SettingKey.breakDuration)
    let prevReset = defaults.object(forKey: SettingKey.forceResetFocusAfterBreak)
    defer {
      restoreDefault(prevWork, key: SettingKey.workDuration)
      restoreDefault(prevBreak, key: SettingKey.breakDuration)
      restoreDefault(prevReset, key: SettingKey.forceResetFocusAfterBreak)
    }
    defaults.set(100.0, forKey: SettingKey.workDuration)
    defaults.set(5.0, forKey: SettingKey.breakDuration)
    defaults.set(true, forKey: SettingKey.forceResetFocusAfterBreak)

    let sm = StateManager()  // timeRemaining ≈ 100
    sm.focusScheduleEnabled = false

    Thread.sleep(forTimeInterval: 1.1)
    sm.start()  // restart so elapsed time is applied to activeEndsAt

    // Flip to false before breaking
    defaults.set(false, forKey: SettingKey.forceResetFocusAfterBreak)
    sm.refreshSettingsForTesting()
    #expect(sm.forceResetFocusAfterBreak == false)

    let workTimeLeft = sm.timeRemaining  // should be ~98–99s by now
    sm.transition(to: .onBreak)  // captures preBreakWorkTimeRemaining ≈ workTimeLeft
    sm.transition(to: .active)  // with forceReset=false, must restore preBreakWorkTimeRemaining

    #expect(
      sm.timeRemaining < 99.5, "Must not reset to full 100s workDuration when forceReset=false")
    #expect(
      abs(sm.timeRemaining - workTimeLeft) < 2.0, "Must resume approximately where it left off")
  }

  @Test func scheduleAutoResumeRestartsWithFullWorkDuration() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    let schedKeys = [
      SettingKey.focusScheduleEnabled, SettingKey.focusScheduleStartMinute,
      SettingKey.focusScheduleEndMinute, SettingKey.focusScheduleWeekdays,
      SettingKey.focusScheduleAutoResume,
    ]
    let prevSched = schedKeys.map { defaults.object(forKey: $0) }
    defer {
      restoreDefault(prevWork, key: SettingKey.workDuration)
      for (i, k) in schedKeys.enumerated() { restoreDefault(prevSched[i], key: k) }
    }
    defaults.set(750.0, forKey: SettingKey.workDuration)

    let sm = StateManager()
    sm.focusScheduleEnabled = true
    sm.focusScheduleStartMinute = 540
    sm.focusScheduleEndMinute = 1080
    sm.focusScheduleWeekdays = "2,3,4,5,6"
    sm.focusScheduleAutoResume = true

    // Sleep outside the window
    sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 20, minute: 0))
    #expect(sm.status == .paused)

    // Auto-resume inside the window
    sm.enforceSchedulePolicyForTesting(now: fixedMonday(hour: 12, minute: 0))
    #expect(sm.status == .active)

    // After auto-resume from schedule sleep, the timer resets to a full work block
    #expect(
      abs(sm.timeRemaining - 750.0) < 1.0,
      "Schedule auto-resume should start a fresh workDuration block, got \(sm.timeRemaining)")
  }

  /// 2024-01-01 is a Monday (Gregorian weekday == 2, Sunday == 1), so schedule tests
  /// that target weekdays "2,3,4,5,6" are deterministic regardless of when they run.
  private func fixedMonday(hour: Int, minute: Int) -> Date {
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 1
    comps.day = 1
    comps.hour = hour
    comps.minute = minute
    comps.second = 0
    return Calendar.current.date(from: comps) ?? Date()
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
