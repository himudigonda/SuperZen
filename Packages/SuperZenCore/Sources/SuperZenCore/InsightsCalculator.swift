import Foundation

public struct InsightsCalculator: Sendable {
  public static let minimumPaceSample: TimeInterval = 900
  public static let goalTolerance: TimeInterval = 0.5
  public static let neutralComponent = 0.5

  public let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func interval(for range: InsightsRange, at now: Date) -> DateInterval {
    let today = calendar.startOfDay(for: now)
    let start = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today) ?? today
    return DateInterval(start: start, end: max(start, now))
  }

  public func comparisonInterval(for range: InsightsRange, at now: Date) -> DateInterval {
    let current = interval(for: range, at: now)
    let start = calendar.date(byAdding: .day, value: -range.dayCount, to: current.start) ?? current.start
    let end = calendar.date(byAdding: .day, value: -range.dayCount, to: current.end) ?? start
    return DateInterval(start: start, end: max(start, end))
  }

  public func fetchStart(for range: InsightsRange, at now: Date, streakLookbackDays: Int) -> Date {
    let today = calendar.startOfDay(for: now)
    let streakStart = calendar.date(byAdding: .day, value: -max(0, streakLookbackDays), to: today) ?? today
    return min(comparisonInterval(for: range, at: now).start, streakStart)
  }

  public func compute(
    _ range: InsightsRange,
    at now: Date,
    data: TelemetrySnapshot,
    configuration: InsightsConfiguration
  ) -> Insights {
    let window = interval(for: range, at: now)
    let goals = configuration.goals
    let days = Double(range.dayCount)
    let active = data.activity.filter { $0.kind == .active }
    let focus = total(active, in: window)
    let idle = total(data.activity.filter { $0.kind == .idle }, in: window)
    let sessionLengths = sessionFocus(active, in: window)
    let interruptions = countInterruptions(data.activity, in: window, threshold: configuration.interruptionThreshold)

    let breaks = data.breaks.filter { window.contains($0.end) }
    let taken = breaks.filter { $0.result.wasTaken }.count
    let skipped = breaks.count - taken
    let wellness = data.wellness.filter { window.contains($0.at) }
    let wellnessDone = wellness.filter(\.completed).count

    let focusRate = ratio(focus, focus + idle)
    let breakRate = ratio(Double(taken), Double(breaks.count))
    let wellnessRate = ratio(Double(wellnessDone), Double(wellness.count))
    let interruptionScore = focus > 0 ? 1 / (1 + Double(interruptions) / (focus / 3600)) : nil

    let buckets = buckets(for: range, window: window, active: active, now: now)
    let comparison = total(active, in: comparisonInterval(for: range, at: now))

    return Insights(
      range: range,
      interval: window,
      focus: focus,
      idle: idle,
      focusRate: focusRate,
      sessions: sessionLengths.count,
      averageSession: sessionLengths.isEmpty ? 0 : sessionLengths.reduce(0, +) / Double(sessionLengths.count),
      longestSession: sessionLengths.max() ?? 0,
      interruptions: interruptions,
      breaksTaken: taken,
      breaksSkipped: skipped,
      breakRate: breakRate,
      skipRate: ratio(Double(skipped), Double(breaks.count)),
      wellnessCompleted: wellnessDone,
      wellnessTotal: wellness.count,
      wellnessRate: wellnessRate,
      wellnessByKind: WellnessKind.allCases.map { kind in
        let scoped = wellness.filter { $0.kind == kind }
        return WellnessTally(kind: kind, completed: scoped.filter(\.completed).count, total: scoped.count)
      },
      focusGoalProgress: min(1, focus / (goals.focusSeconds * days)),
      breakGoalProgress: min(1, Double(taken) / (Double(goals.breaks) * days)),
      wellnessGoalProgress: min(1, Double(wellnessDone) / (Double(goals.wellness) * days)),
      qualityScore: qualityScore(
        [focusRate, breakRate, wellnessRate, interruptionScore], weights: configuration.profile.weights),
      hasData: focus + idle > 0 || !breaks.isEmpty || !wellness.isEmpty,
      streakDays: streak(active: active, goal: goals.focusSeconds, at: now),
      activeDays: range == .today
        ? (focus > 0 ? 1 : 0)
        : buckets.filter { $0.focus > 0 }.count,
      buckets: buckets,
      bestBucket: buckets.filter { $0.focus > 0 }.max { $0.focus < $1.focus },
      trend: comparison > 0 ? (focus - comparison) / comparison : nil,
      forecast: forecast(range, at: now, focus: focus, active: active, configuration: configuration)
    )
  }

  public func streak(active: [ActivityInterval], goal: TimeInterval, at now: Date) -> Int {
    let daily = split(active, by: .day)
    let target = goal - Self.goalTolerance
    var day = calendar.startOfDay(for: now)
    var count = (daily[day] ?? 0) >= target ? 1 : 0
    while let previous = calendar.date(byAdding: .day, value: -1, to: day).map(calendar.startOfDay),
      (daily[previous] ?? 0) >= target
    {
      count += 1
      day = previous
    }
    return count
  }

  func total(_ intervals: [ActivityInterval], in window: DateInterval) -> TimeInterval {
    intervals.reduce(0) { $0 + $1.overlap(with: window) }
  }

  func sessionFocus(_ active: [ActivityInterval], in window: DateInterval) -> [TimeInterval] {
    var bySession: [UUID: TimeInterval] = [:]
    for interval in active {
      let seconds = interval.overlap(with: window)
      if seconds > 0 { bySession[interval.sessionID, default: 0] += seconds }
    }
    return Array(bySession.values)
  }

  func runs(_ activity: [ActivityInterval]) -> [ActivityInterval] {
    var merged: [ActivityInterval] = []
    for interval in activity.sorted(by: { $0.start < $1.start }) {
      if var last = merged.last, last.kind == interval.kind, last.sessionID == interval.sessionID,
        interval.start.timeIntervalSince(last.end) <= TelemetryRecorder.mergeTolerance
      {
        last.end = max(last.end, interval.end)
        merged[merged.count - 1] = last
      } else {
        merged.append(interval)
      }
    }
    return merged
  }

  func countInterruptions(_ activity: [ActivityInterval], in window: DateInterval, threshold: TimeInterval) -> Int {
    runs(activity).filter { run in
      run.kind == .idle && run.duration >= threshold && window.contains(run.start.addingTimeInterval(threshold))
    }.count
  }

  func split(_ intervals: [ActivityInterval], by component: Calendar.Component) -> [Date: TimeInterval] {
    var totals: [Date: TimeInterval] = [:]
    for interval in intervals {
      var cursor = interval.start
      while cursor < interval.end, let unit = calendar.dateInterval(of: component, for: cursor) {
        let pieceEnd = min(interval.end, unit.end)
        totals[unit.start, default: 0] += pieceEnd.timeIntervalSince(cursor)
        cursor = pieceEnd
      }
    }
    return totals
  }

  func buckets(
    for range: InsightsRange, window: DateInterval, active: [ActivityInterval], now: Date
  ) -> [InsightsBucket] {
    let component: Calendar.Component = range == .today ? .hour : .day
    let totals = split(active, by: component)
    guard let lastDay = calendar.dateInterval(of: .day, for: now) else { return [] }
    var result: [InsightsBucket] = []
    var cursor = window.start
    while cursor < lastDay.end, let unit = calendar.dateInterval(of: component, for: cursor) {
      result.append(InsightsBucket(interval: unit, focus: totals[unit.start] ?? 0))
      cursor = unit.end
    }
    return result
  }

  func qualityScore(_ components: [Double?], weights: QualityWeights) -> Int {
    let weightList = [weights.focus, weights.breaks, weights.wellness, weights.interruptions]
    let totalWeight = weightList.reduce(0, +)
    guard totalWeight > 0 else { return 50 }
    let weighted = zip(components, weightList).reduce(0.0) { sum, pair in
      sum + (pair.0 ?? Self.neutralComponent) * pair.1
    }
    return Int((max(0, min(1, weighted / totalWeight)) * 100).rounded())
  }

  func forecast(
    _ range: InsightsRange,
    at now: Date,
    focus: TimeInterval,
    active: [ActivityInterval],
    configuration: InsightsConfiguration
  ) -> Forecast {
    let goal = configuration.goals.focusSeconds
    guard range == .today else {
      let expectedDays = Double(range.dayCount - 1) + todayFraction(at: now, window: configuration.workWindow)
      let expected = expectedDays / Double(range.dayCount)
      let actual = focus / (goal * Double(range.dayCount))
      return .pace(delta: actual - expected)
    }

    let remaining = goal - focus
    if remaining <= Self.goalTolerance { return .goalMet }
    let shift = workShift(at: now, window: configuration.workWindow)
    if now < shift.start { return .beforeWorkday(needed: remaining) }
    if now.isAtOrAfter(shift.end) { return .workdayOver(shortBy: remaining) }

    let elapsed = now.timeIntervalSince(shift.start)
    let focusInShift = total(active, in: DateInterval(start: shift.start, end: now))
    guard elapsed >= Self.minimumPaceSample, focusInShift > 0 else { return .gatheringPace(needed: remaining) }

    let pace = focusInShift / elapsed
    let eta = now.addingTimeInterval(remaining / pace)
    if eta.isAtOrBefore(shift.end) { return .onTrack(eta: eta) }
    return .shortfall(projected: focus + pace * shift.end.timeIntervalSince(now), goal: goal)
  }

  func workShift(at now: Date, window: TimeWindow?) -> DateInterval {
    let today = calendar.startOfDay(for: now)
    let wholeDay = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: today, duration: 86_400)
    guard let window, window.startMinute != window.endMinute else { return wholeDay }
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
    let candidates = [yesterday, today].compactMap { $0 }.compactMap {
      DayProgress.shift(of: window, on: $0, calendar: calendar)
    }
    if let current = candidates.first(where: { now.isAtOrAfter($0.start) && now < $0.end }) { return current }
    return DayProgress.shift(of: window, on: today, calendar: calendar) ?? wholeDay
  }

  func todayFraction(at now: Date, window: TimeWindow?) -> Double {
    let shift = workShift(at: now, window: window)
    guard shift.duration > 0 else { return 0 }
    return max(0, min(1, now.timeIntervalSince(shift.start) / shift.duration))
  }

  private func ratio(_ part: Double, _ whole: Double) -> Double? {
    whole > 0 ? part / whole : nil
  }
}
