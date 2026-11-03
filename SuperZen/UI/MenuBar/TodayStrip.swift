import Combine
import SuperZenCore
import SwiftData
import SwiftUI

@MainActor
final class TodayStripModel: ObservableObject {
  @Published private(set) var summary: TodaySummary?

  private let context: @MainActor () -> ModelContext
  private let defaults: UserDefaults
  private let calendar: Calendar
  private let notificationCenter: NotificationCenter
  private let clock: @MainActor () -> Date
  private let liveActivity: @MainActor () -> ActivityInterval?
  private var subscription: AnyCancellable?
  private var loadTask: Task<Void, Never>?

  init(
    context: @escaping @MainActor () -> ModelContext = { SuperZenApp.sharedModelContainer.mainContext },
    defaults: UserDefaults = .standard,
    calendar: Calendar = .current,
    notificationCenter: NotificationCenter = .default,
    clock: @escaping @MainActor () -> Date = { Date() },
    liveActivity: @escaping @MainActor () -> ActivityInterval? = { TelemetryService.shared.openActivity }
  ) {
    self.context = context
    self.defaults = defaults
    self.calendar = calendar
    self.notificationCenter = notificationCenter
    self.clock = clock
    self.liveActivity = liveActivity
  }

  var isObserving: Bool { subscription != nil }

  func activate() {
    if subscription == nil {
      subscription = notificationCenter.publisher(for: .superZenTelemetryDidChange)
        .sink { [weak self] _ in
          MainActor.assumeIsolated { self?.refresh() }
        }
    }
    refresh()
  }

  func deactivate() {
    subscription = nil
    loadTask?.cancel()
    loadTask = nil
  }

  func refresh() {
    loadTask?.cancel()
    loadTask = Task { [weak self] in
      await Task.yield()
      guard let self, !Task.isCancelled else { return }
      if let computed = self.compute() { self.summary = computed }
    }
  }

  private func compute() -> TodaySummary? {
    let now = clock()
    let start = calendar.startOfDay(for: now)
    guard var snapshot = try? InsightsViewModel.fetchSnapshot(in: context(), from: start, to: now) else {
      return nil
    }
    if let open = liveActivity(), open.end > start { snapshot.activity.append(open) }
    let goals = InsightsGoals(
      focusMinutes: defaults.integer(forKey: SettingKey.dailyFocusGoalMinutes),
      breaks: defaults.integer(forKey: SettingKey.dailyBreakGoalCount),
      wellness: defaults.integer(forKey: SettingKey.dailyWellnessGoalCount))
    let insights = InsightsCalculator(calendar: calendar).compute(
      .today, at: now, data: snapshot, configuration: InsightsConfiguration(goals: goals))
    return TodaySummary(insights: insights, goals: goals)
  }

  deinit {
    loadTask?.cancel()
  }
}

struct TodayStrip: View {
  @StateObject private var model = TodayStripModel()

  var body: some View {
    TodayStripContent(summary: model.summary)
      .onAppear { model.activate() }
      .onDisappear { model.deactivate() }
  }
}

struct TodayStripContent: View {
  let summary: TodaySummary?

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      HStack(alignment: .firstTextBaseline) {
        Text(String(localized: "Today", comment: "Menu bar popover today strip label"))
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
        Spacer()
        Text(focusText)
          .font(ZenFont.titleSmall)
          .foregroundStyle(ZenColor.onSurface)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(ZenColor.outlineVariant)
          Capsule()
            .fill(ZenColor.primary)
            .frame(width: proxy.size.width * (summary?.goalFraction ?? 0))
        }
      }
      .frame(height: ZenSpacing.xs)
      Text(breaksText)
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .lineLimit(1)
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }

  private var focusText: String {
    let focus = InsightsFormat.duration(summary?.focus ?? 0)
    guard let goal = summary?.focusGoal, goal > 0 else {
      return String(localized: "\(focus) focused", comment: "Menu bar popover today strip focus time")
    }
    return String(
      localized: "\(focus) of \(InsightsFormat.duration(goal))",
      comment: "Menu bar popover today strip: focus time against the daily goal")
  }

  private var breaksText: String {
    guard let summary, summary.breaksTotal > 0 else {
      return String(localized: "No breaks yet today", comment: "Menu bar popover today strip empty state")
    }
    return String(
      localized: "Breaks: \(summary.breaksTaken) taken, \(summary.breaksSkipped) skipped",
      comment: "Menu bar popover today strip break counts")
  }
}
