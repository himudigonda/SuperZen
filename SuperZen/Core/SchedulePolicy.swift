import Foundation

enum SchedulePolicy {
  static func weekdaySet(from csv: String) -> Set<Int> {
    Set(csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
  }

  static func weekdayCSV(from set: Set<Int>) -> String {
    set.sorted().map(String.init).joined(separator: ",")
  }

  static func isWithinActiveSchedule(
    now: Date,
    enabled: Bool,
    startMinute: Int,
    endMinute: Int,
    weekdaysCSV: String,
    calendar: Calendar = .current
  ) -> Bool {
    guard enabled else { return true }

    let weekdays = weekdaySet(from: weekdaysCSV)
    let weekday = calendar.component(.weekday, from: now)
    guard weekdays.contains(weekday) else { return false }

    let minuteOfDay =
      calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    return isWithinWindow(minuteOfDay: minuteOfDay, startMinute: startMinute, endMinute: endMinute)
  }

  static func isWithinQuietHours(
    now: Date,
    enabled: Bool,
    startMinute: Int,
    endMinute: Int,
    calendar: Calendar = .current
  ) -> Bool {
    guard enabled else { return false }
    let minuteOfDay =
      calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    return isWithinWindow(minuteOfDay: minuteOfDay, startMinute: startMinute, endMinute: endMinute)
  }

  private static func isWithinWindow(minuteOfDay: Int, startMinute: Int, endMinute: Int) -> Bool {
    let clampedMinute = max(0, min(1439, minuteOfDay))
    let start = max(0, min(1439, startMinute))
    let end = max(0, min(1439, endMinute))

    if start == end {
      return true
    }
    if start < end {
      return clampedMinute >= start && clampedMinute < end
    }
    return clampedMinute >= start || clampedMinute < end
  }
}
