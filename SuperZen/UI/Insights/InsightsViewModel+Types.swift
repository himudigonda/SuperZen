import Foundation
import SuperZenCore

extension InsightsViewModel {
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
}
