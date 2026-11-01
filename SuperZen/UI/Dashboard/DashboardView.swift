import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var viewModel = DashboardViewModel()
  @State private var showClearDataWarning = false
  @State private var clearDataStatusMessage = ""
  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      HStack(spacing: ZenSpacing.sm) {
        VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
          Text("Insights")
            .font(ZenFont.title)
            .foregroundStyle(ZenColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
          Text("Performance, goals, trends, and wellness in one view.")
            .font(ZenFont.subheadline)
            .foregroundStyle(ZenColor.textSecondary)
        }
        Spacer()
        Picker("Range", selection: $viewModel.selectedRange) {
          ForEach(DashboardViewModel.Range.allCases) { range in
            Text(range.rawValue).tag(range)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 250)
        iconButton(
          "arrow.clockwise",
          label: String(localized: "Refresh insights", comment: "Insights toolbar button"),
          tint: ZenColor.accent
        ) {
          viewModel.load(context: modelContext)
        }
        iconButton(
          "trash",
          label: String(localized: "Clear all insights data", comment: "Insights toolbar button"),
          tint: ZenColor.danger
        ) {
          showClearDataWarning = true
        }
      }

      if clearDataStatusMessage.isEmpty == false {
        Text(clearDataStatusMessage)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
      }

      section(
        title: String(localized: "Activity Timeline", comment: "Insights section title"),
        subtitle: viewModel.chartTitle
      ) {
        chartSection
      }

      section(
        title: String(localized: "Core Focus Metrics", comment: "Insights section title"),
        subtitle: String(
          localized: "Sessions and completion rates", comment: "Insights section subtitle")
      ) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 200), spacing: ZenSpacing.md)], spacing: ZenSpacing.md
        ) {
          StatTile(
            String(localized: "Focused minutes", comment: "Insights stat card title"),
            value: "\(viewModel.focusedMinutes)",
            icon: "clock"
          )
          StatTile(
            String(localized: "Sessions", comment: "Insights stat card title"),
            value: "\(viewModel.sessionsCount)",
            icon: "list.bullet.rectangle.portrait"
          )
          StatTile(
            String(localized: "Average session", comment: "Insights stat card title"),
            value: "\(viewModel.averageSessionMinutes)m",
            icon: "equal.circle"
          )
          StatTile(
            String(localized: "Longest session", comment: "Insights stat card title"),
            value: "\(viewModel.longestSessionMinutes)m",
            icon: "timer"
          )
          StatTile(
            String(
              localized: "Break completion (\(viewModel.breakCompletionRate)%)",
              comment: "Insights ratio card title with completion percentage"),
            value: "\(viewModel.breakCompleted)/\(viewModel.breakTotal)",
            caption: String(localized: "Completed", comment: "Insights ratio card caption"),
            icon: "figure.mind.and.body"
          )
          StatTile(
            String(
              localized: "Wellness completion (\(viewModel.wellnessCompletionRate)%)",
              comment: "Insights ratio card title with completion percentage"),
            value: "\(viewModel.wellnessCompleted)/\(viewModel.wellnessTotal)",
            caption: String(localized: "Completed", comment: "Insights ratio card caption"),
            icon: "heart.text.square"
          )
        }
      }

      section(
        title: String(localized: "Apps During Focus", comment: "Insights section title"),
        subtitle: selectedRangeSubtitle
      ) {
        if viewModel.selectedRange == .today {
          if viewModel.workBlockAppSummaries.isEmpty {
            DashboardMessageCard(
              title: String(
                localized: "No work-block app data yet", comment: "Insights message card title"),
              message: String(
                localized:
                  "Complete one focus block and start your next break to see app usage here.",
                comment: "Insights message card body"),
              icon: "apps.iphone"
            )
          } else {
            VStack(alignment: .leading, spacing: ZenSpacing.sm) {
              HStack {
                Text("Selected work block")
                  .font(ZenFont.captionEmphasized)
                  .foregroundStyle(ZenColor.textSecondary)
                Spacer()
                Picker(
                  selection: Binding(
                    get: {
                      viewModel.selectedWorkBlockID
                        ?? viewModel.workBlockAppSummaries.last?.id ?? UUID()
                    },
                    set: { viewModel.selectWorkBlock($0) }
                  ),
                  label: EmptyView()
                ) {
                  ForEach(viewModel.workBlockAppSummaries) { summary in
                    Text("\(summary.label) · \(summary.timeWindow)")
                      .tag(summary.id)
                  }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280)
              }

              if let summary = viewModel.selectedWorkBlockSummary {
                WorkBlockAppsCard(summary: summary)
              }
            }
          }
        } else {
          TopAppsSummaryCard(
            title: String(
              localized: "Top active apps in this range", comment: "Insights card title"),
            apps: viewModel.topAppsInRange
          )
        }
      }

      section(
        title: String(localized: "Goals & Momentum", comment: "Insights section title"),
        subtitle: String(
          localized: "Progress and consistency signals", comment: "Insights section subtitle")
      ) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 200), spacing: ZenSpacing.md)], spacing: ZenSpacing.md
        ) {
          StatTile(
            String(localized: "Focus goal", comment: "Insights goal card title"),
            value: "\(viewModel.focusedMinutes)m",
            caption: targetCaption(rangeScaledText(base: viewModel.focusGoalMinutes, suffix: "m")),
            progress: viewModel.focusGoalProgress,
            tint: ZenColor.accent
          )
          StatTile(
            String(localized: "Break goal", comment: "Insights goal card title"),
            value: "\(viewModel.breakCompleted)",
            caption: targetCaption(rangeScaledText(base: viewModel.breakGoalCount, suffix: " breaks")),
            progress: viewModel.breakGoalProgress,
            tint: ZenColor.success
          )
          StatTile(
            String(localized: "Wellness goal", comment: "Insights goal card title"),
            value: "\(viewModel.wellnessCompleted)",
            caption: targetCaption(rangeScaledText(base: viewModel.wellnessGoalCount, suffix: " reminders")),
            progress: viewModel.wellnessGoalProgress,
            tint: ZenColor.warning
          )
          StatTile(
            String(localized: "Trend vs previous period", comment: "Insights card title"),
            value: trendText,
            caption: String(localized: "Same range comparison", comment: "Insights card subtitle"),
            icon: "chart.line.uptrend.xyaxis"
          )
          StatTile(
            String(localized: "Best period", comment: "Insights card title"),
            value: viewModel.bestBucketLabel,
            caption: String(
              localized: "Most active bucket in this range", comment: "Insights card subtitle"),
            icon: "sparkles"
          )
          StatTile(
            String(localized: "Consistency streak", comment: "Insights card title"),
            value: String(
              localized: "\(viewModel.consistencyStreakDays) days",
              comment: "Insights card value: consistency streak length in days"),
            caption: String(
              localized: "\(viewModel.activeDaysCount) active days in range",
              comment: "Insights card subtitle: active days within the selected range"),
            icon: "flame.fill"
          )
        }
      }

      section(
        title: String(localized: "Focus Quality Signals", comment: "Insights section title"),
        subtitle: String(
          localized: "Behavior and interruption impact", comment: "Insights section subtitle")
      ) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 200), spacing: ZenSpacing.md)], spacing: ZenSpacing.md
        ) {
          StatTile(
            String(localized: "Focus quality score", comment: "Insights card title"),
            value: "\(viewModel.focusQualityScore)/100",
            caption: String(
              localized: "Weighted by activity, breaks, wellness, and interruptions",
              comment: "Insights card subtitle"),
            icon: "checkmark.seal.fill"
          )
          StatTile(
            String(localized: "Idle minutes", comment: "Insights card title"),
            value: "\(viewModel.idleMinutes)m",
            caption: String(localized: "Within selected range", comment: "Insights card subtitle"),
            icon: "pause.circle"
          )
          StatTile(
            String(localized: "Interruptions", comment: "Insights card title"),
            value: "\(viewModel.interruptionsCount)",
            caption: String(
              localized: "Idle spikes above threshold", comment: "Insights card subtitle"),
            icon: "waveform.path.ecg"
          )
          StatTile(
            String(localized: "Skipped breaks", comment: "Insights card title"),
            value: "\(viewModel.skippedBreakCount)",
            caption: String(
              localized: "Breaks dismissed before completion", comment: "Insights card subtitle"),
            icon: "forward.end"
          )
        }
      }

      section(
        title: String(localized: "Forecast & Wellness Mix", comment: "Insights section title"),
        subtitle: String(
          localized: "Forward-looking guidance", comment: "Insights section subtitle")
      ) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 200), spacing: ZenSpacing.md)], spacing: ZenSpacing.md
        ) {
          DashboardMessageCard(
            title: String(localized: "Goal forecast", comment: "Insights message card title"),
            message: viewModel.forecastText,
            icon: "calendar.badge.clock"
          )
          WellnessBreakdownCard(stats: viewModel.wellnessTypeStats)
        }
      }
    }
    .task {
      viewModel.load(context: modelContext)
    }
    .onChange(of: viewModel.selectedRange) { _, _ in
      viewModel.refreshForSelectedRange()
    }
    .alert("Clear all insights and analytics data?", isPresented: $showClearDataWarning) {
      Button("Cancel", role: .cancel) {}
      Button("Clear All Data", role: .destructive) {
        clearAllInsightsData()
      }
    } message: {
      Text(
        "This permanently deletes all sessions, breaks, wellness events, and per-app work-block data. This cannot be undone."
      )
    }
  }

  private var trendText: String {
    guard viewModel.trendAvailable else {
      return String(localized: "No baseline", comment: "Insights trend value when the previous range has no focus")
    }
    let delta = viewModel.trendDeltaPercent
    if delta > 0 { return "+\(delta)%" }
    return "\(delta)%"
  }

  private var selectedRangeSubtitle: String {
    switch viewModel.selectedRange {
    case .today:
      return String(
        localized: "Per-work-block app activity and session windows",
        comment: "Insights section subtitle for the Today range")
    case .week:
      return String(
        localized: "Most active apps across the last 7 days",
        comment: "Insights section subtitle for the Week range")
    case .month:
      return String(
        localized: "Most active apps across the last 30 days",
        comment: "Insights section subtitle for the Month range")
    }
  }

  private func rangeScaledText(base: Int, suffix: String) -> String {
    let multiplier: Int
    switch viewModel.selectedRange {
    case .today:
      multiplier = 1
    case .week:
      multiplier = 7
    case .month:
      multiplier = 30
    }
    return "\(base * multiplier)\(suffix)"
  }

  private func targetCaption(_ target: String) -> String {
    String(localized: "Target \(target)", comment: "Insights goal card caption with target")
  }

  private func iconButton(
    _ systemImage: String, label: String, tint: ZenColor, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(ZenFont.bodyEmphasized)
        .foregroundStyle(tint)
        .padding(ZenSpacing.xs)
        .background(Circle().fill(tint.opacity(0.16)))
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
  }

  private func section<Content: View>(
    title: String, subtitle: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      SectionHeader(title, subtitle: subtitle)
      content()
    }
  }

  private var chartSection: some View {
    Chart {
      ForEach(viewModel.chartPoints) { point in
        BarMark(
          x: .value("Bucket", point.label),
          y: .value("Minutes", point.minutes)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [color(.accent), color(.accentSecondary)],
            startPoint: .bottom,
            endPoint: .top)
        )
        .cornerRadius(ZenRadius.xs / 2)
      }

      if viewModel.showGoalLine, let goal = viewModel.chartGoalValue {
        RuleMark(y: .value("Goal", goal))
          .foregroundStyle(color(.warning))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .annotation(position: .topTrailing) {
            Text("Goal \(Int(goal.rounded()))m")
              .font(ZenFont.captionEmphasized)
              .foregroundStyle(ZenColor.textSecondary)
              .padding(.horizontal, ZenSpacing.xs)
              .padding(.vertical, ZenSpacing.xxs)
              .background(.thinMaterial, in: Capsule())
              .overlay(Capsule().strokeBorder(ZenColor.controlStroke, lineWidth: 1))
          }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading)
    }
    .frame(height: 240)
    .padding(ZenSpacing.sm)
    .zenSurface()
  }

  private func color(_ role: ZenColorRole) -> Color {
    theme.color(role, scheme: colorScheme)
  }

  private func clearAllInsightsData() {
    let summary = TelemetryService.shared.clearAllTelemetryData()
    clearDataStatusMessage = String(
      localized:
        "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app usage).",
      comment: "Status message after clearing all Insights/analytics data, with per-category counts"
    )
    viewModel.load(context: modelContext)
  }
}
