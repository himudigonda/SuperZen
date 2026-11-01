import Foundation

enum InsightsFormat {
  static func duration(_ seconds: TimeInterval) -> String {
    let totalMinutes = seconds.isFinite ? max(0, Int((seconds / 60).rounded(.down))) : 0
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return "\(minutes)m" }
    return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
  }

  static func trend(_ fraction: Double?) -> String {
    guard let fraction, fraction.isFinite else {
      return String(localized: "No baseline", comment: "Insights trend value when the previous range has no focus")
    }
    let points = Int((fraction * 100).rounded())
    return points > 0 ? "+\(points)%" : "\(points)%"
  }

  static func bucket(_ date: Date, range: InsightsViewModel.Range) -> String {
    switch range {
    case .today: return date.formatted(.dateTime.hour())
    case .week: return date.formatted(.dateTime.weekday(.wide))
    case .month: return date.formatted(.dateTime.month(.abbreviated).day())
    }
  }

  static func weekday(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated))
  }

  static func hour(_ hour: Int, on day: Date, calendar: Calendar = .current) -> String {
    let date = calendar.date(bySettingHour: min(23, max(0, hour)), minute: 0, second: 0, of: day) ?? day
    return date.formatted(.dateTime.hour())
  }

  static func clock(_ date: Date) -> String {
    date.formatted(.dateTime.hour().minute())
  }
}
