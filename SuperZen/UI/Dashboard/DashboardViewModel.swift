import Combine
import Foundation
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
  enum Range: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"

    var id: Self { self }

    var chartTitle: String {
      switch self {
      case .today:
        return "Hourly active minutes"
      case .week:
        return "Daily active minutes (last 7 days)"
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
      }
    }()

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

    let rangedWellness = wellness.filter { $0.timestamp >= rangeStart }
    wellnessTotal = rangedWellness.count
    wellnessCompleted = rangedWellness.filter { $0.action == "completed" }.count

    switch selectedRange {
    case .today:
      chartPoints = buildHourlyPoints(
        sessions: rangedSessions, dayStart: todayStart, calendar: calendar)
    case .week:
      chartPoints = buildDailyPoints(
        sessions: rangedSessions,
        weekStart: rangeStart,
        calendar: calendar
      )
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

  private func buildDailyPoints(
    sessions: [SessionSample], weekStart: Date, calendar: Calendar
  ) -> [ChartPoint] {
    var buckets: [String: Double] = [:]
    for session in sessions {
      let dayStart = calendar.startOfDay(for: session.startTime)
      let key = dayStart.formatted(.iso8601.year().month().day())
      buckets[key, default: 0] += session.activeSeconds / 60.0
    }

    return (0..<7).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
        return nil
      }
      let dayKey = day.formatted(.iso8601.year().month().day())
      let label = day.formatted(.dateTime.weekday(.abbreviated))
      return ChartPoint(
        id: "day-\(dayKey)",
        label: label,
        minutes: buckets[dayKey, default: 0.0]
      )
    }
  }
}
