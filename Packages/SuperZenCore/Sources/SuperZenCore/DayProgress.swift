import Foundation

public struct DayProgress: Equatable, Sendable {
  public var fraction: Double
  public var elapsed: TimeInterval
  public var remaining: TimeInterval

  public init(fraction: Double, elapsed: TimeInterval, remaining: TimeInterval) {
    self.fraction = fraction
    self.elapsed = elapsed
    self.remaining = remaining
  }

  public static let zero = DayProgress(fraction: 0, elapsed: 0, remaining: 0)

  public static func compute(window: TimeWindow, at now: Date, calendar: Calendar) -> DayProgress {
    guard window.startMinute != window.endMinute else { return .zero }
    let today = calendar.startOfDay(for: now)
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return .zero }

    for day in [today, yesterday] {
      guard let interval = shift(of: window, on: day, calendar: calendar) else { continue }
      if now >= interval.start && now < interval.end {
        return progress(in: interval, at: now)
      }
    }

    if let todayShift = shift(of: window, on: today, calendar: calendar), now >= todayShift.end {
      return DayProgress(fraction: 1, elapsed: todayShift.duration, remaining: 0)
    }
    return .zero
  }

  private static func shift(of window: TimeWindow, on day: Date, calendar: Calendar) -> DateInterval? {
    guard let start = date(on: day, minute: window.startMinute, calendar: calendar) else { return nil }
    let endDay = window.crossesMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day
    guard let endDay, let end = date(on: endDay, minute: window.endMinute, calendar: calendar), end > start
    else { return nil }
    return DateInterval(start: start, end: end)
  }

  private static func date(on day: Date, minute: Int, calendar: Calendar) -> Date? {
    calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
  }

  private static func progress(in interval: DateInterval, at now: Date) -> DayProgress {
    let elapsed = now.timeIntervalSince(interval.start)
    return DayProgress(
      fraction: max(0, min(1, elapsed / interval.duration)),
      elapsed: max(0, elapsed),
      remaining: max(0, interval.end.timeIntervalSince(now)))
  }
}
