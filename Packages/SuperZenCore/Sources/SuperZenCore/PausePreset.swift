import Foundation

public enum PausePreset: String, CaseIterable, Sendable {
  case fifteenMinutes
  case oneHour
  case twoHours
  case untilTomorrow

  public static let fallbackStartMinute = 9 * 60

  public func duration(at now: Date, schedule: FocusSchedule, calendar: Calendar) -> TimeInterval {
    switch self {
    case .fifteenMinutes: return 15 * 60
    case .oneHour: return 3600
    case .twoHours: return 2 * 3600
    case .untilTomorrow:
      let target = Self.nextStart(after: now, schedule: schedule, calendar: calendar)
      return max(1, target.timeIntervalSince(now))
    }
  }

  static func nextStart(after now: Date, schedule: FocusSchedule, calendar: Calendar) -> Date {
    let useSchedule = schedule.enabled && !schedule.weekdays.isEmpty
    let minute = useSchedule ? schedule.window.startMinute : fallbackStartMinute
    let components = DateComponents(hour: minute / 60, minute: minute % 60, second: 0)
    var cursor = now
    for _ in 0..<8 {
      guard
        let candidate = calendar.nextDate(
          after: cursor, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .first,
          direction: .forward)
      else { break }
      if !useSchedule || schedule.weekdays.contains(calendar.component(.weekday, from: candidate)) {
        return candidate
      }
      cursor = candidate
    }
    return now.addingTimeInterval(24 * 3600)
  }
}
