import Foundation

public enum WellnessKind: String, CaseIterable, Codable, Sendable {
  case posture, blink, water, affirmation

  public var displayDuration: TimeInterval {
    switch self {
    case .posture, .blink, .water: return 0.75
    case .affirmation: return 2.0
    }
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
