import Foundation
import SuperZenCore

extension InsightsViewModel {
  static func makeKPIs(for result: Insights, range: Range, configuration: InsightsConfiguration) -> [KPI] {
    let days = range.dayCount
    let focusGoal = configuration.goals.focusSeconds * Double(days)
    let breakGoal = configuration.goals.breaks * days
    return [
      KPI(
        kind: .focus,
        title: String(localized: "Focus", comment: "Insights KPI title"),
        value: InsightsFormat.duration(result.focus),
        caption: String(
          localized: "of \(InsightsFormat.duration(focusGoal)) goal",
          comment: "Insights KPI caption: focus goal for the selected range"),
        progress: result.focusGoalProgress,
        icon: "target"),
      KPI(
        kind: .breaks,
        title: String(localized: "Breaks taken", comment: "Insights KPI title"),
        value: "\(result.breaksTaken)",
        caption: String(
          localized: "Goal \(breakGoal), \(result.breaksSkipped) skipped",
          comment: "Insights KPI caption: break goal and skipped breaks"),
        progress: result.breakGoalProgress,
        icon: "eye"),
      KPI(
        kind: .streak,
        title: String(localized: "Streak", comment: "Insights KPI title"),
        value: String(
          localized: "\(result.streakDays) days", comment: "Insights KPI value: consecutive days at focus goal"),
        caption: String(localized: "Days in a row at your focus goal", comment: "Insights KPI caption"),
        progress: nil,
        icon: "flame"),
      KPI(
        kind: .quality,
        title: String(localized: "Quality", comment: "Insights KPI title"),
        value: result.hasData ? "\(result.qualityScore)" : InsightsFormat.noValue,
        caption: String(
          localized: "\(SettingsCatalog.scoringProfileDisplayName(configuration.profile.rawValue)) score out of 100",
          comment: "Insights KPI caption: scoring profile"),
        progress: result.hasData ? Double(result.qualityScore) / 100 : nil,
        icon: "checkmark.seal"),
    ]
  }

  static func makeDetails(for result: Insights, range: Range) -> [DetailStat] {
    [
      DetailStat(
        id: "sessions", title: String(localized: "Sessions", comment: "Insights detail title"),
        value: "\(result.sessions)", icon: "square.stack"),
      DetailStat(
        id: "average", title: String(localized: "Average session", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.averageSession), icon: "equal.circle"),
      DetailStat(
        id: "longest", title: String(localized: "Longest session", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.longestSession), icon: "timer"),
      DetailStat(
        id: "idle", title: String(localized: "Idle time", comment: "Insights detail title"),
        value: InsightsFormat.duration(result.idle), icon: "pause.circle"),
      DetailStat(
        id: "interruptions", title: String(localized: "Interruptions", comment: "Insights detail title"),
        value: "\(result.interruptions)", icon: "waveform.path.ecg"),
      DetailStat(
        id: "trend", title: String(localized: "Versus previous period", comment: "Insights detail title"),
        value: InsightsFormat.trend(result.trend), icon: "chart.line.uptrend.xyaxis"),
      DetailStat(
        id: "best", title: String(localized: "Best period", comment: "Insights detail title"),
        value: result.bestBucket.map { InsightsFormat.bucket($0.interval.start, range: range) }
          ?? String(localized: "None yet", comment: "Insights best period placeholder"),
        icon: "sparkles"),
      DetailStat(
        id: "wellness", title: String(localized: "Wellness done", comment: "Insights detail title"),
        value: "\(result.wellnessCompleted)/\(result.wellnessTotal)", icon: "heart"),
    ]
  }

  static func percent(_ fraction: Double?) -> Int {
    Int(saturating: ((fraction ?? 0) * 100).rounded())
  }

  static func describe(_ forecast: Forecast) -> String {
    let minutes = { (seconds: TimeInterval) in InsightsFormat.duration(seconds) }
    switch forecast {
    case .goalMet:
      return String(localized: "Focus goal reached for today.", comment: "Insights forecast")
    case .beforeWorkday(let needed):
      return String(
        localized: "Your workday has not started. Today's goal needs \(minutes(needed)) of focus.",
        comment: "Insights forecast")
    case .gatheringPace(let needed):
      return String(
        localized: "\(minutes(needed)) more focus to reach today's goal.", comment: "Insights forecast")
    case .onTrack(let eta):
      return String(
        localized: "On pace to reach your goal around \(eta.formatted(.dateTime.hour().minute())).",
        comment: "Insights forecast")
    case .shortfall(let projected, let goal):
      return String(
        localized:
          "At this pace you will reach about \(minutes(projected)) of your \(minutes(goal)) goal by end of day.",
        comment: "Insights forecast")
    case .workdayOver(let shortBy):
      return String(
        localized: "Workday over, \(minutes(shortBy)) short of today's goal.", comment: "Insights forecast")
    case .pace(let delta):
      let gap = abs(delta).formatted(.percent.precision(.fractionLength(0)))
      return delta >= 0
        ? String(localized: "Ahead of pace by \(gap).", comment: "Insights forecast")
        : String(localized: "Behind pace by \(gap).", comment: "Insights forecast")
    }
  }
}

extension TimelineLane {
  var title: String {
    switch self {
    case .focus: return String(localized: "Focus", comment: "Insights timeline lane")
    case .idle: return String(localized: "Idle", comment: "Insights timeline lane")
    case .rest: return String(localized: "Breaks", comment: "Insights timeline lane")
    }
  }
}
