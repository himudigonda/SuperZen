import SwiftUI

nonisolated enum ZenTimeFormat {
  static let minutesPerDay = 1440

  static func clamp(_ minuteOfDay: Int) -> Int {
    min(minutesPerDay - 1, max(0, minuteOfDay))
  }

  static func string(minuteOfDay: Int, locale: Locale = .autoupdatingCurrent) -> String {
    let utc = TimeZone(secondsFromGMT: 0) ?? .gmt
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    calendar.locale = locale
    let date = Date(timeIntervalSinceReferenceDate: TimeInterval(clamp(minuteOfDay) * 60))
    let style = Date.FormatStyle(
      date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: utc)
    return date.formatted(style)
  }

  static func options(stepMinutes: Int, including extra: [Int] = []) -> [Int] {
    let step = min(120, max(5, stepMinutes))
    let grid = stride(from: 0, to: minutesPerDay, by: step).map { $0 }
    return Array(Set(grid + extra.map(clamp))).sorted()
  }
}

nonisolated enum TimeRangeIssue: Equatable, Sendable {
  case empty
  case endBeforeStart

  var message: String {
    switch self {
    case .empty:
      return String(
        localized: "Start and end can't be the same time.",
        comment: "Time range validation: zero-length range")
    case .endBeforeStart:
      return String(
        localized: "End time must be after the start time.",
        comment: "Time range validation: end before start")
    }
  }
}

nonisolated enum TimeRangeRule: Sendable {
  case sameDay
  case allowsOvernight

  func issue(start: Int, end: Int) -> TimeRangeIssue? {
    let start = ZenTimeFormat.clamp(start)
    let end = ZenTimeFormat.clamp(end)
    if start == end { return .empty }
    if self == .sameDay && end < start { return .endBeforeStart }
    return nil
  }

  func isSelectableStart(_ start: Int, options: [Int]) -> Bool {
    options.contains { issue(start: start, end: $0) == nil }
  }

  func adjustedEnd(start: Int, end: Int, options: [Int]) -> Int {
    guard issue(start: start, end: end) != nil else { return end }
    return options.first { $0 > start && issue(start: start, end: $0) == nil }
      ?? options.first { issue(start: start, end: $0) == nil }
      ?? end
  }
}

struct TimeRangePicker: View {
  @Binding private var startMinute: Int
  @Binding private var endMinute: Int
  private let rule: TimeRangeRule
  private let stepMinutes: Int
  @Environment(\.locale) private var locale

  init(
    start: Binding<Int>,
    end: Binding<Int>,
    rule: TimeRangeRule = .allowsOvernight,
    stepMinutes: Int = 30
  ) {
    self._startMinute = start
    self._endMinute = end
    self.rule = rule
    self.stepMinutes = stepMinutes
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: ZenSpacing.xxs) {
      HStack(spacing: ZenSpacing.xs) {
        timeMenu(
          String(localized: "Start time", comment: "Time range picker: start time label"),
          value: startMinute,
          isEnabled: { rule.isSelectableStart($0, options: options) },
          select: selectStart
        )
        Image(
          systemName: rule == .allowsOvernight && endMinute < startMinute
            ? "moon.fill" : "arrow.right"
        )
        .font(ZenFont.iconSmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .accessibilityHidden(true)
        timeMenu(
          String(localized: "End time", comment: "Time range picker: end time label"),
          value: endMinute,
          isEnabled: { rule.issue(start: startMinute, end: $0) == nil },
          select: { endMinute = $0 }
        )
      }
      if let issue = rule.issue(start: startMinute, end: endMinute) {
        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.error)
      }
    }
  }

  private var options: [Int] {
    ZenTimeFormat.options(stepMinutes: stepMinutes, including: [startMinute, endMinute])
  }

  private func selectStart(_ minute: Int) {
    startMinute = minute
    endMinute = rule.adjustedEnd(start: minute, end: endMinute, options: options)
  }

  private func timeMenu(
    _ title: String, value: Int, isEnabled: @escaping (Int) -> Bool,
    select: @escaping (Int) -> Void
  ) -> some View {
    let text = ZenTimeFormat.string(minuteOfDay: value, locale: locale)
    let items: [ZenMenuItem] = options.map { minute in
      .action(
        id: "\(minute)", ZenTimeFormat.string(minuteOfDay: minute, locale: locale), isSelected: minute == value,
        isEnabled: isEnabled(minute)
      ) { select(minute) }
    }
    return ZenMenu(items: items) {
      PickerPill(text: text)
    }
    .accessibilityLabel(title)
    .accessibilityValue(text)
  }
}
