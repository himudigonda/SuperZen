import Foundation

public enum SchedulePolicy {
  public static func weekdaySet(from csv: String) -> Set<Int> {
    Set(
      csv.split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        .filter { (1...7).contains($0) })
  }

  public static func weekdayCSV(from set: Set<Int>) -> String {
    set.sorted().map(String.init).joined(separator: ",")
  }

  public static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  }

  public static func isWithinSchedule(_ schedule: FocusSchedule, at now: Date, calendar: Calendar) -> Bool {
    guard schedule.enabled else { return true }
    let window = schedule.window
    let minute = minuteOfDay(now, calendar: calendar)
    let weekday = calendar.component(.weekday, from: now)
    if !window.crossesMidnight || minute >= window.startMinute {
      return schedule.weekdays.contains(weekday) && window.contains(minuteOfDay: minute)
    }
    let previousWeekday = weekday == 1 ? 7 : weekday - 1
    return schedule.weekdays.contains(previousWeekday) && window.contains(minuteOfDay: minute)
  }

  public static func isWithinQuietHours(_ quietHours: QuietHours, at now: Date, calendar: Calendar) -> Bool {
    guard quietHours.enabled else { return false }
    return quietHours.window.contains(minuteOfDay: minuteOfDay(now, calendar: calendar))
  }
}
