import Foundation

public enum TimelineLane: String, CaseIterable, Sendable {
  case focus
  case idle
  case rest
}

public struct TimelineSegment: Equatable, Sendable {
  public var lane: TimelineLane
  public var interval: DateInterval

  public init(lane: TimelineLane, interval: DateInterval) {
    self.lane = lane
    self.interval = interval
  }
}

public struct DayTimeline: Equatable, Sendable {
  public var domain: DateInterval
  public var segments: [TimelineSegment]

  public init(domain: DateInterval, segments: [TimelineSegment]) {
    self.domain = domain
    self.segments = segments
  }

  public var isEmpty: Bool { segments.isEmpty }

  public func total(_ lane: TimelineLane) -> TimeInterval {
    segments.filter { $0.lane == lane }.reduce(0) { $0 + $1.interval.duration }
  }
}

public struct HeatmapCell: Equatable, Sendable {
  public var day: Date
  public var hour: Int
  public var focus: TimeInterval

  public init(day: Date, hour: Int, focus: TimeInterval) {
    self.day = day
    self.hour = hour
    self.focus = focus
  }
}

public struct HourlyHeatmap: Equatable, Sendable {
  public var days: [Date]
  public var cells: [HeatmapCell]

  public init(days: [Date], cells: [HeatmapCell]) {
    self.days = days
    self.cells = cells
  }

  public var peak: HeatmapCell? {
    cells.filter { $0.focus > 0 }.max { $0.focus < $1.focus }
  }

  public var isEmpty: Bool { peak == nil }
}

extension InsightsCalculator {
  public static let timelineGapTolerance: TimeInterval = 2
  public static let minimumTimelineSpan: TimeInterval = 4 * 3600
  public static let hoursPerDay = 24
  public static let maximumHeatmapDays = 366

  public func timeline(on day: Date, at now: Date, data: TelemetrySnapshot) -> DayTimeline {
    let dayInterval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86_400)
    let visibleEnd = min(dayInterval.end, max(dayInterval.start, now))
    let window = DateInterval(start: dayInterval.start, end: visibleEnd)

    let activity = runs(data.activity).compactMap { run -> TimelineSegment? in
      clip(run.start, run.end, to: window).map {
        TimelineSegment(lane: run.kind == .active ? .focus : .idle, interval: $0)
      }
    }
    let rests = data.breaks.filter { $0.result.wasTaken && $0.rested > 0 }.compactMap { record in
      clip(record.start, record.end, to: window).map { TimelineSegment(lane: .rest, interval: $0) }
    }

    let segments = TimelineLane.allCases.flatMap { lane in
      coalesce((activity + rests).filter { $0.lane == lane })
    }
    .sorted { ($0.interval.start, laneOrder($0.lane)) < ($1.interval.start, laneOrder($1.lane)) }

    return DayTimeline(domain: domain(for: segments, day: dayInterval, now: now), segments: segments)
  }

  public func hourlyHeatmap(days dayCount: Int, at now: Date, active: [ActivityInterval]) -> HourlyHeatmap {
    let count = min(max(1, dayCount), Self.maximumHeatmapDays)
    let today = calendar.startOfDay(for: now)
    let days = (0..<count).reversed().compactMap {
      calendar.date(byAdding: .day, value: -$0, to: today).map(calendar.startOfDay)
    }
    guard let first = days.first else { return HourlyHeatmap(days: [], cells: []) }
    let window = DateInterval(start: first, end: max(first, now))

    let clipped = active.filter { $0.kind == .active }.compactMap { interval -> ActivityInterval? in
      clip(interval.start, interval.end, to: window).map {
        ActivityInterval(sessionID: interval.sessionID, kind: .active, start: $0.start, end: $0.end)
      }
    }

    var totals: [Date: [Int: TimeInterval]] = [:]
    for (hourStart, seconds) in split(clipped, by: .hour) {
      let day = calendar.startOfDay(for: hourStart)
      let hour = calendar.component(.hour, from: hourStart)
      totals[day, default: [:]][hour, default: 0] += seconds
    }

    let cells = days.flatMap { day in
      (0..<Self.hoursPerDay).map { hour in
        HeatmapCell(day: day, hour: hour, focus: totals[day]?[hour] ?? 0)
      }
    }
    return HourlyHeatmap(days: days, cells: cells)
  }

  func clip(_ start: Date, _ end: Date, to window: DateInterval) -> DateInterval? {
    let lower = max(start, window.start)
    let upper = min(end, window.end)
    return upper > lower ? DateInterval(start: lower, end: upper) : nil
  }

  func coalesce(_ segments: [TimelineSegment]) -> [TimelineSegment] {
    var merged: [TimelineSegment] = []
    for segment in segments.sorted(by: { $0.interval.start < $1.interval.start }) {
      if var last = merged.last,
        segment.interval.start.timeIntervalSince(last.interval.end) <= Self.timelineGapTolerance
      {
        last.interval = DateInterval(start: last.interval.start, end: max(last.interval.end, segment.interval.end))
        merged[merged.count - 1] = last
      } else {
        merged.append(segment)
      }
    }
    return merged
  }

  func domain(for segments: [TimelineSegment], day: DateInterval, now: Date) -> DateInterval {
    let anchor = min(max(now, day.start), day.end)
    let earliest = segments.map(\.interval.start).min() ?? anchor
    let latest = max(segments.map(\.interval.end).max() ?? anchor, anchor)
    var lower = floorHour(earliest, within: day)
    var upper = ceilHour(latest, within: day)
    if upper.timeIntervalSince(lower) < Self.minimumTimelineSpan {
      lower = max(day.start, upper.addingTimeInterval(-Self.minimumTimelineSpan))
      upper = min(day.end, lower.addingTimeInterval(Self.minimumTimelineSpan))
    }
    return DateInterval(start: lower, end: upper)
  }

  private func floorHour(_ date: Date, within day: DateInterval) -> Date {
    max(day.start, calendar.dateInterval(of: .hour, for: date)?.start ?? date)
  }

  private func ceilHour(_ date: Date, within day: DateInterval) -> Date {
    guard let hour = calendar.dateInterval(of: .hour, for: date) else { return min(day.end, date) }
    return min(day.end, hour.start == date ? date : hour.end)
  }

  private func laneOrder(_ lane: TimelineLane) -> Int {
    TimelineLane.allCases.firstIndex(of: lane) ?? 0
  }
}
