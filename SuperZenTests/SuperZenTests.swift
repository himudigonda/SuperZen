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

  private func date(_ day: Date, hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
  }
}
