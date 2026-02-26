import Foundation
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
