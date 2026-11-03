import Foundation

public struct PlannedBreak: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var minuteOfDay: Int
  public var weekdays: Set<Int>
  public var duration: TimeInterval

  public init(id: String, minuteOfDay: Int, weekdays: Set<Int>, duration: TimeInterval) {
    self.id = id
    self.minuteOfDay = minuteOfDay
    self.weekdays = weekdays
    self.duration = duration
  }

  var validated: PlannedBreak {
    PlannedBreak(
      id: id,
      minuteOfDay: TimeWindow.clamp(minuteOfDay),
      weekdays: weekdays.filter { (1...7).contains($0) },
      duration: duration.isFinite && duration >= Settings.minimumDuration
        ? min(duration, Settings.maximumDuration) : TimerSettings().longBreakDuration)
  }

  public static func list(fromJSON text: String) -> [PlannedBreak] {
    guard let data = text.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([PlannedBreak].self, from: data)) ?? []
  }

  public static func json(from list: [PlannedBreak]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(list) else { return "[]" }
    return String(data: data, encoding: .utf8) ?? "[]"
  }
}
