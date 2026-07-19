import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var viewModel = DashboardViewModel()
  @State private var showClearDataWarning = false
  @State private var clearDataStatusMessage = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Insights")
            .font(.title2.weight(.bold))
          Text("Performance, goals, trends, and wellness in one view.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
        }
        Spacer()
        Picker("Range", selection: $viewModel.selectedRange) {
          ForEach(DashboardViewModel.Range.allCases) { range in
            Text(range.rawValue).tag(range)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 250)
        Button {
          viewModel.load(context: modelContext)
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 14, weight: .semibold))
            .padding(8)
            .background(Circle().fill(Theme.accent.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .help("Refresh insights")

        Button(role: .destructive) {
          showClearDataWarning = true
        } label: {
          Image(systemName: "trash")
            .font(.system(size: 14, weight: .semibold))
            .padding(8)
            .background(Circle().fill(.red.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help("Clear all insights data")
      }

      if clearDataStatusMessage.isEmpty == false {
        Text(clearDataStatusMessage)
          .font(.caption.weight(.medium))
          .foregroundStyle(Theme.textSecondary)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
          DashboardStatCard(
            title: String(localized: "Focused minutes", comment: "Insights stat card title"),
            value: "\(viewModel.focusedMinutes)",
            icon: "clock"
          )
          DashboardStatCard(
            title: String(localized: "Sessions", comment: "Insights stat card title"),
            value: "\(viewModel.sessionsCount)",
            icon: "list.bullet.rectangle.portrait"
          )
          DashboardStatCard(
            title: String(localized: "Average session", comment: "Insights stat card title"),
            value: "\(viewModel.averageSessionMinutes)m",
            icon: "equal.circle"
          )
          DashboardStatCard(
            title: String(localized: "Longest session", comment: "Insights stat card title"),
            value: "\(viewModel.longestSessionMinutes)m",
            icon: "timer"
          )
          DashboardRatioCard(
            title: String(
              localized: "Break completion (\(viewModel.breakCompletionRate)%)",
              comment: "Insights ratio card title with completion percentage"),
            completed: viewModel.breakCompleted,
            total: viewModel.breakTotal,
            icon: "figure.mind.and.body"
          )
          DashboardRatioCard(
            title: String(
              localized: "Wellness completion (\(viewModel.wellnessCompletionRate)%)",
              comment: "Insights ratio card title with completion percentage"),
            completed: viewModel.wellnessCompleted,
            total: viewModel.wellnessTotal,
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
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("Selected work block")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.textSecondary)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
          DashboardGoalCard(
            title: String(localized: "Focus goal", comment: "Insights goal card title"),
            progress: viewModel.focusGoalProgress,
            valueText: "\(viewModel.focusedMinutes)m",
            targetText: rangeScaledText(base: viewModel.focusGoalMinutes, suffix: "m"),
            tint: .blue
          )
          DashboardGoalCard(
            title: String(localized: "Break goal", comment: "Insights goal card title"),
            progress: viewModel.breakGoalProgress,
            valueText: "\(viewModel.breakCompleted)",
            targetText: rangeScaledText(base: viewModel.breakGoalCount, suffix: " breaks"),
            tint: .green
          )
          DashboardGoalCard(
            title: String(localized: "Wellness goal", comment: "Insights goal card title"),
            progress: viewModel.wellnessGoalProgress,
            valueText: "\(viewModel.wellnessCompleted)",
            targetText: rangeScaledText(base: viewModel.wellnessGoalCount, suffix: " reminders"),
            tint: .orange
          )
          DashboardInsightCard(
            title: String(localized: "Trend vs previous period", comment: "Insights card title"),
            value: trendText,
            subtitle: String(localized: "Same range comparison", comment: "Insights card subtitle"),
            icon: "chart.line.uptrend.xyaxis"
          )
          DashboardInsightCard(
            title: String(localized: "Best period", comment: "Insights card title"),
            value: viewModel.bestBucketLabel,
            subtitle: String(
              localized: "Most active bucket in this range", comment: "Insights card subtitle"),
            icon: "sparkles"
          )
          DashboardInsightCard(
            title: String(localized: "Consistency streak", comment: "Insights card title"),
            value: String(
              localized: "\(viewModel.consistencyStreakDays) days",
              comment: "Insights card value: consistency streak length in days"),
            subtitle: String(
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
          DashboardInsightCard(
            title: String(localized: "Focus quality score", comment: "Insights card title"),
            value: "\(viewModel.focusQualityScore)/100",
            subtitle: String(
              localized: "Weighted by activity, breaks, wellness, and interruptions",
              comment: "Insights card subtitle"),
            icon: "checkmark.seal.fill"
          )
          DashboardInsightCard(
            title: String(localized: "Idle minutes", comment: "Insights card title"),
            value: "\(viewModel.idleMinutes)m",
            subtitle: String(localized: "Within selected range", comment: "Insights card subtitle"),
            icon: "pause.circle"
          )
          DashboardInsightCard(
            title: String(localized: "Interruptions", comment: "Insights card title"),
            value: "\(viewModel.interruptionsCount)",
            subtitle: String(
              localized: "Idle spikes above threshold", comment: "Insights card subtitle"),
            icon: "waveform.path.ecg"
          )
          DashboardInsightCard(
            title: String(localized: "Skipped breaks", comment: "Insights card title"),
            value: "\(viewModel.skippedBreakCount)",
            subtitle: String(
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
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

  @ViewBuilder
  private func section<Content: View>(
    title: String, subtitle: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.headline.weight(.semibold))
          .foregroundStyle(Theme.textPrimary)
        Text(subtitle)
          .font(.caption.weight(.medium))
          .foregroundStyle(Theme.textSecondary)
      }
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
        .foregroundStyle(Theme.accentGradient)
        .cornerRadius(3)
      }

      if viewModel.showGoalLine, let goal = viewModel.chartGoalValue {
        RuleMark(y: .value("Goal", goal))
          .foregroundStyle(StyleGuide.goalLine)
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .annotation(position: .topTrailing) {
            Text("Goal \(Int(goal.rounded()))m")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(Theme.textSecondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.thinMaterial, in: Capsule())
              .overlay(Capsule().stroke(Theme.pillStroke, lineWidth: 1))
          }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading)
    }
    .frame(height: 240)
    .padding(12)
    .background {
      let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Theme.surfaceStroke, lineWidth: 1)
    )
    .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 6)
  }

  private func clearAllInsightsData() {
    TelemetryService.shared.setup(context: modelContext)
    let summary = TelemetryService.shared.clearAllTelemetryData()
    clearDataStatusMessage = String(
      localized:
        "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app usage).",
      comment: "Status message after clearing all Insights/analytics data, with per-category counts"
    )
    viewModel.load(context: modelContext)
  }
}

private enum StyleGuide {
  static let goalLine = Color.orange.opacity(0.9)
}
