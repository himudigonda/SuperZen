import Foundation

public enum BreakDifficulty: String, CaseIterable, Codable, Sendable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"

  public var id: String { rawValue }
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
  public var maxPostpones: Int = 2

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
