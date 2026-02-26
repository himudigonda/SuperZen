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
    let now = Date()
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

    let sessionDescriptor = FetchDescriptor<FocusSession>(
      predicate: #Predicate { $0.startTime >= rangeStart })
    let sessions = (try? context.fetch(sessionDescriptor)) ?? []
    let totalActive = sessions.reduce(0.0) { $0 + $1.activeSeconds }

    focusedMinutes = Int(totalActive / 60.0)
    sessionsCount = sessions.count
    averageSessionMinutes =
      sessions.isEmpty ? 0 : Int((totalActive / Double(sessions.count)) / 60.0)
    longestSessionMinutes = Int((sessions.map(\.activeSeconds).max() ?? 0.0) / 60.0)

    let breakDescriptor = FetchDescriptor<BreakEvent>(
      predicate: #Predicate { $0.timestamp >= rangeStart })
    let breaks = (try? context.fetch(breakDescriptor)) ?? []
    breakTotal = breaks.count
    breakCompleted = breaks.filter(\.wasCompleted).count

    let wellnessDescriptor = FetchDescriptor<WellnessEvent>(
      predicate: #Predicate { $0.timestamp >= rangeStart })
    let wellnessEvents = (try? context.fetch(wellnessDescriptor)) ?? []
    wellnessTotal = wellnessEvents.count
    wellnessCompleted = wellnessEvents.filter { $0.action == "completed" }.count

    switch selectedRange {
    case .today:
      chartPoints = buildHourlyPoints(sessions: sessions, dayStart: todayStart, calendar: calendar)
    case .week:
      chartPoints = buildDailyPoints(sessions: sessions, weekStart: rangeStart, calendar: calendar)
    }
  }

  private func buildHourlyPoints(
    sessions: [FocusSession], dayStart: Date, calendar: Calendar
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
    sessions: [FocusSession], weekStart: Date, calendar: Calendar
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
