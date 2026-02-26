import Combine
import Foundation
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
  enum Range: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var id: Self { self }

    var chartTitle: String {
      switch self {
      case .today:
        return "Hourly active minutes"
      case .week:
        return "Daily active minutes (last 7 days)"
      case .month:
        return "Daily active minutes (last 30 days)"
      }
    }

    var dayCount: Int {
      switch self {
      case .today:
        return 1
      case .week:
        return 7
      case .month:
        return 30
      }
    }
  }

  struct ChartPoint: Identifiable {
    let id: String
    let label: String
    let minutes: Double
  }

  struct SessionSample {
    let startTime: Date
    let activeSeconds: Double
  }

  struct BreakSample {
    let timestamp: Date
    let wasCompleted: Bool
  }

  struct WellnessSample {
    let timestamp: Date
    let action: String
  }

  @Published var selectedRange: Range = .today

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
  @Published var bestBucketLabel: String = "No activity yet"
  @Published var trendDeltaPercent: Int = 0
  @Published var consistencyStreakDays: Int = 0
  @Published var focusGoalMinutes: Int = 240
  @Published var breakGoalCount: Int = 6
  @Published var wellnessGoalCount: Int = 8
  @Published var focusGoalProgress: Double = 0
  @Published var breakGoalProgress: Double = 0
  @Published var wellnessGoalProgress: Double = 0
  @Published var showGoalLine: Bool = true
  @Published var chartGoalValue: Double?
  @Published var chartPoints: [ChartPoint] = []

  var chartTitle: String { selectedRange.chartTitle }

  func refresh(context: ModelContext) {
    let sessionDescriptor = FetchDescriptor<FocusSession>()
    let sessions = ((try? context.fetch(sessionDescriptor)) ?? []).map {
      SessionSample(startTime: $0.startTime, activeSeconds: $0.activeSeconds)
    }

    let breakDescriptor = FetchDescriptor<BreakEvent>()
    let breaks = ((try? context.fetch(breakDescriptor)) ?? []).map {
      BreakSample(timestamp: $0.timestamp, wasCompleted: $0.wasCompleted)
    }

    let wellnessDescriptor = FetchDescriptor<WellnessEvent>()
    let wellness = ((try? context.fetch(wellnessDescriptor)) ?? []).map {
      WellnessSample(timestamp: $0.timestamp, action: $0.action)
    }

    refresh(now: Date(), sessions: sessions, breaks: breaks, wellness: wellness)
  }

  func refresh(
    now: Date,
    sessions: [SessionSample],
    breaks: [BreakSample],
    wellness: [WellnessSample]
  ) {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: now)
    let rangeStart: Date = {
      switch selectedRange {
      case .today:
        return todayStart
      case .week:
        return calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
      case .month:
        return calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
      }
    }()
    let dayCount = selectedRange.dayCount

    let rangedSessions = sessions.filter { $0.startTime >= rangeStart }
    let totalActive = rangedSessions.reduce(0.0) { $0 + $1.activeSeconds }

    focusedMinutes = Int(totalActive / 60.0)
    sessionsCount = rangedSessions.count
    averageSessionMinutes =
      rangedSessions.isEmpty ? 0 : Int((totalActive / Double(rangedSessions.count)) / 60.0)
    longestSessionMinutes = Int((rangedSessions.map(\.activeSeconds).max() ?? 0.0) / 60.0)

    let rangedBreaks = breaks.filter { $0.timestamp >= rangeStart }
    breakTotal = rangedBreaks.count
    breakCompleted = rangedBreaks.filter(\.wasCompleted).count
    breakCompletionRate =
      breakTotal > 0 ? Int((Double(breakCompleted) / Double(breakTotal) * 100).rounded()) : 0

    let rangedWellness = wellness.filter { $0.timestamp >= rangeStart }
    wellnessTotal = rangedWellness.count
    wellnessCompleted = rangedWellness.filter { $0.action == "completed" }.count
    wellnessCompletionRate =
      wellnessTotal > 0
      ? Int((Double(wellnessCompleted) / Double(wellnessTotal) * 100).rounded()) : 0

    let defaults = UserDefaults.standard
    focusGoalMinutes = max(1, defaults.integer(forKey: SettingKey.dailyFocusGoalMinutes))
    breakGoalCount = max(1, defaults.integer(forKey: SettingKey.dailyBreakGoalCount))
    wellnessGoalCount = max(1, defaults.integer(forKey: SettingKey.dailyWellnessGoalCount))
    showGoalLine = defaults.bool(forKey: SettingKey.insightsShowGoalLine)

    let rangeFocusGoalMinutes = focusGoalMinutes * dayCount
    let rangeBreakGoalCount = breakGoalCount * dayCount
    let rangeWellnessGoalCount = wellnessGoalCount * dayCount
    focusGoalProgress = min(
      1, rangeFocusGoalMinutes > 0 ? Double(focusedMinutes) / Double(rangeFocusGoalMinutes) : 0)
    breakGoalProgress = min(
      1, rangeBreakGoalCount > 0 ? Double(breakCompleted) / Double(rangeBreakGoalCount) : 0)
    wellnessGoalProgress = min(
      1, rangeWellnessGoalCount > 0 ? Double(wellnessCompleted) / Double(rangeWellnessGoalCount) : 0
    )

    activeDaysCount = Set(rangedSessions.map { calendar.startOfDay(for: $0.startTime) }).count
    consistencyStreakDays = focusGoalStreakDays(sessions: sessions, now: now, calendar: calendar)

    let previousRangeStart =
      calendar.date(byAdding: .day, value: -dayCount, to: rangeStart) ?? rangeStart
    let previousRangeEnd = rangeStart
    let previousSessions = sessions.filter {
      $0.startTime >= previousRangeStart && $0.startTime < previousRangeEnd
    }
    let previousTotalActive = previousSessions.reduce(0.0) { $0 + $1.activeSeconds }
    if previousTotalActive > 0 {
      trendDeltaPercent =
        Int((((totalActive - previousTotalActive) / previousTotalActive) * 100.0).rounded())
    } else {
      trendDeltaPercent = totalActive > 0 ? 100 : 0
    }

    switch selectedRange {
    case .today:
      chartPoints = buildHourlyPoints(
        sessions: rangedSessions, dayStart: todayStart, calendar: calendar)
      chartGoalValue = showGoalLine ? max(1, Double(focusGoalMinutes) / 8.0) : nil
    case .week:
      chartPoints = buildDailyPoints(
        sessions: rangedSessions,
        weekStart: rangeStart,
        days: 7,
        format: .weekday,
        calendar: calendar
      )
      chartGoalValue = showGoalLine ? Double(focusGoalMinutes) : nil
    case .month:
      chartPoints = buildDailyPoints(
        sessions: rangedSessions,
        weekStart: rangeStart,
        days: 30,
        format: .dayOfMonth,
        calendar: calendar
      )
      chartGoalValue = showGoalLine ? Double(focusGoalMinutes) : nil
    }

    if let best = chartPoints.max(by: { $0.minutes < $1.minutes }), best.minutes > 0 {
      bestBucketLabel = best.label
    } else {
      bestBucketLabel = "No activity yet"
    }
  }

  private func buildHourlyPoints(
    sessions: [SessionSample], dayStart: Date, calendar: Calendar
  ) -> [ChartPoint] {
    var buckets: [Int: Double] = Dictionary(uniqueKeysWithValues: (0..<24).map { ($0, 0.0) })
    for session in sessions {
      let hour = calendar.component(.hour, from: session.startTime)
      buckets[hour, default: 0] += session.activeSeconds / 60.0
    }
    return (0..<24).map { hour in
      let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) ?? dayStart
      let label = date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
      return ChartPoint(
        id: "hour-\(hour)",
        label: label,
        minutes: buckets[hour, default: 0.0]
      )
    }
  }

  private enum DailyLabelFormat {
    case weekday
    case dayOfMonth
  }

  private func buildDailyPoints(
    sessions: [SessionSample],
    weekStart: Date,
    days: Int,
    format: DailyLabelFormat,
    calendar: Calendar
  ) -> [ChartPoint] {
    var buckets: [String: Double] = [:]
    for session in sessions {
      let dayStart = calendar.startOfDay(for: session.startTime)
      let key = dayStart.formatted(.iso8601.year().month().day())
      buckets[key, default: 0] += session.activeSeconds / 60.0
    }

    return (0..<days).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
        return nil
      }
      let dayKey = day.formatted(.iso8601.year().month().day())
      let label: String
      switch format {
      case .weekday:
        label = day.formatted(.dateTime.weekday(.abbreviated))
      case .dayOfMonth:
        label = day.formatted(.dateTime.day(.defaultDigits))
      }
      return ChartPoint(
        id: "day-\(dayKey)",
        label: label,
        minutes: buckets[dayKey, default: 0.0]
      )
    }
  }

  private func focusGoalStreakDays(
    sessions: [SessionSample],
    now: Date,
    calendar: Calendar
  ) -> Int {
    let goalSeconds = Double(max(1, focusGoalMinutes)) * 60.0
    guard goalSeconds > 0 else { return 0 }

    var byDay: [Date: Double] = [:]
    for session in sessions {
      let day = calendar.startOfDay(for: session.startTime)
      byDay[day, default: 0] += session.activeSeconds
    }

    var streak = 0
    for offset in 0..<30 {
      guard
        let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))
      else {
        continue
      }
      let total = byDay[day, default: 0]
      if total >= goalSeconds {
        streak += 1
      } else {
        break
      }
    }
    return streak
  }
}
