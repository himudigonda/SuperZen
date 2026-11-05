import Foundation

public struct TimeWindow: Codable, Equatable, Sendable {
  public static let minutesPerDay = 1440

  public var startMinute: Int
  public var endMinute: Int

  public init(startMinute: Int, endMinute: Int) {
    self.startMinute = Self.clamp(startMinute)
    self.endMinute = Self.clamp(endMinute)
  }

  public var crossesMidnight: Bool { endMinute < startMinute }

  public func contains(minuteOfDay: Int) -> Bool {
    let minute = Self.clamp(minuteOfDay)
    if startMinute == endMinute { return true }
    if startMinute < endMinute { return minute >= startMinute && minute < endMinute }
    return minute >= startMinute || minute < endMinute
  }

  var normalized: TimeWindow { TimeWindow(startMinute: startMinute, endMinute: endMinute) }

  static func clamp(_ minute: Int) -> Int {
    max(0, min(minutesPerDay - 1, minute))
  }
}

public struct FocusSchedule: Codable, Equatable, Sendable {
  public var enabled: Bool = false
  public var window = TimeWindow(startMinute: 540, endMinute: 1080)
  public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
  public var autoResume: Bool = true

  public init() {}
}

public struct QuietHours: Codable, Equatable, Sendable {
  public var enabled: Bool = false
  public var window = TimeWindow(startMinute: 1320, endMinute: 420)

  public init() {}
}
