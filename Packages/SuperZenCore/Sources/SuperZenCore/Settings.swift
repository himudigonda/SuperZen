import Foundation

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
  public var deferral = DeferralSettings()
  public var plannedBreaks: [PlannedBreak] = []

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
    copy.timer.maxPostpones = max(0, timer.maxPostpones)
    copy.deferral = deferral.validated()
    copy.plannedBreaks = plannedBreaks.map(\.validated)
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
