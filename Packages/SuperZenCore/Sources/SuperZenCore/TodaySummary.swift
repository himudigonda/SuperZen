import Foundation

public struct TodaySummary: Equatable, Sendable {
  public let focus: TimeInterval
  public let focusGoal: TimeInterval
  public let goalFraction: Double
  public let breaksTaken: Int
  public let breaksSkipped: Int

  public init(insights: Insights, focusGoal: TimeInterval) {
    let goal = focusGoal.isFinite ? max(0, focusGoal) : 0
    let focus = insights.focus.isFinite ? max(0, insights.focus) : 0
    self.focus = focus
    self.focusGoal = goal
    self.goalFraction = Self.fraction(focus, of: goal)
    self.breaksTaken = max(0, insights.breaksTaken)
    self.breaksSkipped = max(0, insights.breaksSkipped)
  }

  public init(insights: Insights, goals: InsightsGoals) {
    self.init(insights: insights, focusGoal: goals.focusSeconds)
  }

  public var isGoalMet: Bool { focusGoal > 0 && focus >= focusGoal }
  public var breaksTotal: Int { breaksTaken + breaksSkipped }
  public var hasActivity: Bool { focus > 0 || breaksTotal > 0 }
  public var goalPercent: Int { Int.saturating((goalFraction * 100).rounded(.down)) }

  private static func fraction(_ value: TimeInterval, of goal: TimeInterval) -> Double {
    guard goal > 0 else { return 0 }
    let ratio = value / goal
    return ratio.isNaN ? 0 : min(1, max(0, ratio))
  }
}
