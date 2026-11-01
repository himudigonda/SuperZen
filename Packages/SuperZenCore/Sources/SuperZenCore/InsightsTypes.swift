import Foundation

public enum InsightsRange: String, CaseIterable, Sendable {
  case today
  case week
  case month

  public var dayCount: Int {
    switch self {
    case .today: return 1
    case .week: return 7
    case .month: return 30
    }
  }
}

public struct QualityWeights: Equatable, Sendable {
  public var focus: Double
  public var breaks: Double
  public var wellness: Double
  public var interruptions: Double

  public init(focus: Double, breaks: Double, wellness: Double, interruptions: Double) {
    self.focus = focus
    self.breaks = breaks
    self.wellness = wellness
    self.interruptions = interruptions
  }
}

public enum ScoringProfile: String, CaseIterable, Sendable {
  case balanced = "Balanced"
  case deepFocus = "Deep Focus"
  case recovery = "Recovery"

  public var weights: QualityWeights {
    switch self {
    case .balanced: return QualityWeights(focus: 0.4, breaks: 0.2, wellness: 0.2, interruptions: 0.2)
    case .deepFocus: return QualityWeights(focus: 0.55, breaks: 0.1, wellness: 0.1, interruptions: 0.25)
    case .recovery: return QualityWeights(focus: 0.25, breaks: 0.35, wellness: 0.3, interruptions: 0.1)
    }
  }
}

public struct InsightsGoals: Equatable, Sendable {
  public var focusMinutes: Int
  public var breaks: Int
  public var wellness: Int

  public init(focusMinutes: Int, breaks: Int, wellness: Int) {
    self.focusMinutes = max(1, focusMinutes)
    self.breaks = max(1, breaks)
    self.wellness = max(1, wellness)
  }

  public var focusSeconds: TimeInterval { TimeInterval(focusMinutes) * 60 }
}

public struct InsightsConfiguration: Equatable, Sendable {
  public var goals: InsightsGoals
  public var profile: ScoringProfile
  public var workWindow: TimeWindow?
  public var interruptionThreshold: TimeInterval

  public init(
    goals: InsightsGoals,
    profile: ScoringProfile = .balanced,
    workWindow: TimeWindow? = nil,
    interruptionThreshold: TimeInterval = 30
  ) {
    self.goals = goals
    self.profile = profile
    self.workWindow = workWindow
    self.interruptionThreshold = interruptionThreshold.isFinite ? max(1, interruptionThreshold) : 30
  }
}

public struct TelemetrySnapshot: Equatable, Sendable {
  public var activity: [ActivityInterval]
  public var breaks: [BreakRecord]
  public var wellness: [WellnessRecord]

  public init(activity: [ActivityInterval] = [], breaks: [BreakRecord] = [], wellness: [WellnessRecord] = []) {
    self.activity = activity
    self.breaks = breaks
    self.wellness = wellness
  }

  public init(records: [TelemetryRecord]) {
    self.init()
    for record in records {
      switch record {
      case .activity(let interval): activity.append(interval)
      case .breakTaken(let record): breaks.append(record)
      case .wellness(let record): wellness.append(record)
      }
    }
  }
}

public struct InsightsBucket: Equatable, Sendable {
  public var interval: DateInterval
  public var focus: TimeInterval

  public init(interval: DateInterval, focus: TimeInterval) {
    self.interval = interval
    self.focus = focus
  }
}

public struct WellnessTally: Equatable, Sendable {
  public var kind: WellnessKind
  public var completed: Int
  public var total: Int

  public init(kind: WellnessKind, completed: Int, total: Int) {
    self.kind = kind
    self.completed = completed
    self.total = total
  }

  public var rate: Double? { total > 0 ? Double(completed) / Double(total) : nil }
}

public enum Forecast: Equatable, Sendable {
  case goalMet
  case beforeWorkday(needed: TimeInterval)
  case gatheringPace(needed: TimeInterval)
  case onTrack(eta: Date)
  case shortfall(projected: TimeInterval, goal: TimeInterval)
  case workdayOver(shortBy: TimeInterval)
  case pace(delta: Double)
}

public struct Insights: Equatable, Sendable {
  public var range: InsightsRange
  public var interval: DateInterval
  public var focus: TimeInterval
  public var idle: TimeInterval
  public var focusRate: Double?
  public var sessions: Int
  public var averageSession: TimeInterval
  public var longestSession: TimeInterval
  public var interruptions: Int
  public var breaksTaken: Int
  public var breaksSkipped: Int
  public var breakRate: Double?
  public var skipRate: Double?
  public var wellnessCompleted: Int
  public var wellnessTotal: Int
  public var wellnessRate: Double?
  public var wellnessByKind: [WellnessTally]
  public var focusGoalProgress: Double
  public var breakGoalProgress: Double
  public var wellnessGoalProgress: Double
  public var qualityScore: Int
  public var hasData: Bool
  public var streakDays: Int
  public var activeDays: Int
  public var buckets: [InsightsBucket]
  public var bestBucket: InsightsBucket?
  public var trend: Double?
  public var forecast: Forecast
}
