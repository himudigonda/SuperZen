import Foundation

public enum BreakDifficulty: String, CaseIterable, Codable, Sendable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"

  public var id: String { rawValue }
}

public enum WellnessKind: String, CaseIterable, Codable, Sendable {
  case posture, blink, water, affirmation

  public var displayDuration: TimeInterval {
    switch self {
    case .posture, .blink, .water: return 0.75
    case .affirmation: return 2.0
    }
  }
}

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

public struct TimerSettings: Codable, Equatable, Sendable {
  public var workDuration: TimeInterval = 1200
  public var shortBreakDuration: TimeInterval = 20
  public var longBreakDuration: TimeInterval = 300
  public var longBreakEvery: Int = 4
  public var nudgeLeadTime: TimeInterval = 10
  public var deferWhileTyping: Bool = true
  public var typingDeferralCap: TimeInterval = 120
  public var naturalBreakMinimum: TimeInterval = 120
  public var idleThreshold: TimeInterval = 20
  public var resetFocusAfterBreak: Bool = true
  public var snoozeDuration: TimeInterval = 300

  public init() {}

  public func duration(of kind: BreakKind) -> TimeInterval {
    switch kind {
    case .short: return shortBreakDuration
    case .long: return longBreakDuration
    }
  }

  public var naturalBreakThreshold: TimeInterval {
    max(shortBreakDuration, naturalBreakMinimum)
  }
}

public struct SkipPolicy: Codable, Equatable, Sendable {
  public static let maxLockSeconds: TimeInterval = 20
  public static let lockRatioRange: ClosedRange<Double> = 0.1...0.9

  public var difficulty: BreakDifficulty = .balanced
  public var balancedLockRatio: Double = 0.5

  public init(difficulty: BreakDifficulty = .balanced, balancedLockRatio: Double = 0.5) {
    self.difficulty = difficulty
    self.balancedLockRatio = balancedLockRatio
  }

  public func lockDuration(forBreakOf planned: TimeInterval) -> TimeInterval {
    let ratio = min(Self.lockRatioRange.upperBound, max(Self.lockRatioRange.lowerBound, balancedLockRatio))
    return min(Self.maxLockSeconds, planned * ratio)
  }
}

public struct Reminder: Codable, Equatable, Sendable {
  public var enabled: Bool
  public var interval: TimeInterval

  public init(enabled: Bool, interval: TimeInterval) {
    self.enabled = enabled
    self.interval = interval
  }
}

public struct WellnessSettings: Codable, Equatable, Sendable {
  public static let multiplierRange: ClosedRange<Double> = 0.1...2.0

  public var posture = Reminder(enabled: true, interval: 1800)
  public var blink = Reminder(enabled: true, interval: 600)
  public var water = Reminder(enabled: true, interval: 3600)
  public var affirmation = Reminder(enabled: true, interval: 3600)
  public var durationMultiplier: Double = 1.0

  public init() {}

  public subscript(kind: WellnessKind) -> Reminder {
    get {
      switch kind {
      case .posture: return posture
      case .blink: return blink
      case .water: return water
      case .affirmation: return affirmation
      }
    }
    set {
      switch kind {
      case .posture: posture = newValue
      case .blink: blink = newValue
      case .water: water = newValue
      case .affirmation: affirmation = newValue
      }
    }
  }

  public func displayDuration(of kind: WellnessKind) -> TimeInterval {
    let multiplier = min(Self.multiplierRange.upperBound, max(Self.multiplierRange.lowerBound, durationMultiplier))
    return kind.displayDuration * multiplier
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

public struct Settings: Codable, Equatable, Sendable {
  public static let currentVersion = 1
  public static let minimumDuration: TimeInterval = 1
  public static let maximumDuration: TimeInterval = 86_400

  public var version: Int = Settings.currentVersion
  public var timer = TimerSettings()
  public var skipPolicy = SkipPolicy()
  public var wellness = WellnessSettings()
  public var schedule = FocusSchedule()
  public var quietHours = QuietHours()

  public init() {}

  public func validated() -> Settings {
    var copy = self
    let defaults = TimerSettings()
    copy.timer.workDuration = Self.positive(timer.workDuration, fallback: defaults.workDuration)
    copy.timer.shortBreakDuration = Self.positive(timer.shortBreakDuration, fallback: defaults.shortBreakDuration)
    copy.timer.longBreakDuration = Self.positive(timer.longBreakDuration, fallback: defaults.longBreakDuration)
    copy.timer.longBreakEvery = max(0, timer.longBreakEvery)
    copy.timer.nudgeLeadTime = timer.nudgeLeadTime < copy.timer.workDuration ? max(0, timer.nudgeLeadTime) : 0
    copy.timer.typingDeferralCap = Self.bounded(timer.typingDeferralCap)
    copy.timer.naturalBreakMinimum = Self.bounded(timer.naturalBreakMinimum)
    copy.timer.idleThreshold = Self.positive(timer.idleThreshold, fallback: defaults.idleThreshold)
    copy.timer.snoozeDuration = Self.positive(timer.snoozeDuration, fallback: defaults.snoozeDuration)
    copy.skipPolicy.balancedLockRatio = min(
      SkipPolicy.lockRatioRange.upperBound, max(SkipPolicy.lockRatioRange.lowerBound, skipPolicy.balancedLockRatio))
    for kind in WellnessKind.allCases {
      let reminder = wellness[kind]
      copy.wellness[kind].interval = Self.positive(reminder.interval, fallback: WellnessSettings()[kind].interval)
    }
    copy.wellness.durationMultiplier = min(
      WellnessSettings.multiplierRange.upperBound,
      max(WellnessSettings.multiplierRange.lowerBound, wellness.durationMultiplier))
    copy.schedule.weekdays = schedule.weekdays.filter { (1...7).contains($0) }
    copy.schedule.window = schedule.window.normalized
    copy.quietHours.window = quietHours.window.normalized
    return copy
  }

  private static func positive(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
    value.isFinite && value >= minimumDuration ? min(value, maximumDuration) : fallback
  }

  private static func bounded(_ value: TimeInterval) -> TimeInterval {
    value.isNaN ? 0 : min(max(0, value), maximumDuration)
  }
}

public enum SettingsCodec {
  public static func encode(_ settings: Settings) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(settings)
  }

  public static func decode(_ data: Data) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: data).validated()
  }
}
