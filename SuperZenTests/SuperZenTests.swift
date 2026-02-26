import Foundation
import SwiftData
import Testing

@testable import SuperZen

@Suite(.serialized)
@MainActor
struct SuperZenTests {
  @Test func stateTransitions() {
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
    #expect(abs(stateManager.timeRemaining - 1.5) < 0.1)

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
    let previousReset = defaults.object(forKey: SettingKey.forceResetFocusAfterBreak)
    defer { restoreDefault(previousReset, key: SettingKey.forceResetFocusAfterBreak) }
    defaults.set(false, forKey: SettingKey.forceResetFocusAfterBreak)

    let stateManager = StateManager()
    stateManager.focusScheduleEnabled = false
    stateManager.workDuration = 8

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
    let stateManager = StateManager()
    stateManager.focusScheduleEnabled = false
    stateManager.workDuration = 300
    let baseline = stateManager.timeRemaining

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
    let previousReset = defaults.object(forKey: SettingKey.forceResetFocusAfterBreak)
    defer { restoreDefault(previousReset, key: SettingKey.forceResetFocusAfterBreak) }

    defaults.set(false, forKey: SettingKey.forceResetFocusAfterBreak)
    let stateManager = StateManager()
    stateManager.workDuration = 4
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
    #expect(abs(stateManager.timeRemaining - 3.0) < 0.2)
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
    let sessions = [
      DashboardViewModel.SessionSample(
        startTime: now.addingTimeInterval(-1800),
        activeSeconds: 1200,
        idleSeconds: 300,
        interruptions: 1
      ),
      DashboardViewModel.SessionSample(
        startTime: now.addingTimeInterval(-900),
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
    let schema = Schema([FocusSession.self, BreakEvent.self, WellnessEvent.self])
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

    try context.save()

    let summary = service.pruneHistoricalData(retainingDays: 90, now: now)

    #expect(summary.sessionsDeleted == 1)
    #expect(summary.breaksDeleted == 1)
    #expect(summary.wellnessDeleted == 0)
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
