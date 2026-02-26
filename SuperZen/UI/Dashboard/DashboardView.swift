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

      section(title: "Activity Timeline", subtitle: viewModel.chartTitle) {
        chartSection
      }

      section(title: "Core Focus Metrics", subtitle: "Sessions and completion rates") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
          DashboardStatCard(
            title: "Focused minutes",
            value: "\(viewModel.focusedMinutes)",
            icon: "clock"
          )
          DashboardStatCard(
            title: "Sessions",
            value: "\(viewModel.sessionsCount)",
            icon: "list.bullet.rectangle.portrait"
          )
          DashboardStatCard(
            title: "Average session",
            value: "\(viewModel.averageSessionMinutes)m",
            icon: "equal.circle"
          )
          DashboardStatCard(
            title: "Longest session",
            value: "\(viewModel.longestSessionMinutes)m",
            icon: "timer"
          )
          DashboardRatioCard(
            title: "Break completion (\(viewModel.breakCompletionRate)%)",
            completed: viewModel.breakCompleted,
            total: viewModel.breakTotal,
            icon: "figure.mind.and.body"
          )
          DashboardRatioCard(
            title: "Wellness completion (\(viewModel.wellnessCompletionRate)%)",
            completed: viewModel.wellnessCompleted,
            total: viewModel.wellnessTotal,
            icon: "heart.text.square"
          )
        }
      }

      section(
        title: "Apps During Focus",
        subtitle: selectedRangeSubtitle
      ) {
        if viewModel.selectedRange == .today {
          if viewModel.workBlockAppSummaries.isEmpty {
            DashboardMessageCard(
              title: "No work-block app data yet",
              message: "Complete one focus block and start your next break to see app usage here.",
              icon: "apps.iphone"
            )
          } else {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("Selected work block")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.textSecondary)
                Spacer()
                Menu {
                  ForEach(viewModel.workBlockAppSummaries) { summary in
                    Button(summary.timeWindow) {
                      viewModel.selectWorkBlock(summary.id)
                    }
                  }
                } label: {
                  Label(
                    viewModel.selectedWorkBlockSummary?.timeWindow ?? "Choose block",
                    systemImage: "chevron.up.chevron.down"
                  )
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.textPrimary)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 7)
                  .background(.thinMaterial, in: Capsule())
                  .overlay(Capsule().stroke(Theme.pillStroke, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
              }

              if let summary = viewModel.selectedWorkBlockSummary {
                WorkBlockAppsCard(summary: summary)
              }
            }
          }
        } else {
          TopAppsSummaryCard(
            title: "Top active apps in this range",
            apps: viewModel.topAppsInRange
          )
        }
      }

      section(title: "Goals & Momentum", subtitle: "Progress and consistency signals") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
          DashboardGoalCard(
            title: "Focus goal",
            progress: viewModel.focusGoalProgress,
            valueText: "\(viewModel.focusedMinutes)m",
            targetText: rangeScaledText(base: viewModel.focusGoalMinutes, suffix: "m"),
            tint: .blue
          )
          DashboardGoalCard(
            title: "Break goal",
            progress: viewModel.breakGoalProgress,
            valueText: "\(viewModel.breakCompleted)",
            targetText: rangeScaledText(base: viewModel.breakGoalCount, suffix: " breaks"),
            tint: .green
          )
          DashboardGoalCard(
            title: "Wellness goal",
            progress: viewModel.wellnessGoalProgress,
            valueText: "\(viewModel.wellnessCompleted)",
            targetText: rangeScaledText(base: viewModel.wellnessGoalCount, suffix: " reminders"),
            tint: .orange
          )
          DashboardInsightCard(
            title: "Trend vs previous period",
            value: trendText,
            subtitle: "Same range comparison",
            icon: "chart.line.uptrend.xyaxis"
          )
          DashboardInsightCard(
            title: "Best period",
            value: viewModel.bestBucketLabel,
            subtitle: "Most active bucket in this range",
            icon: "sparkles"
          )
          DashboardInsightCard(
            title: "Consistency streak",
            value: "\(viewModel.consistencyStreakDays) days",
            subtitle: "\(viewModel.activeDaysCount) active days in range",
            icon: "flame.fill"
          )
        }
      }

      section(title: "Focus Quality Signals", subtitle: "Behavior and interruption impact") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
          DashboardInsightCard(
            title: "Focus quality score",
            value: "\(viewModel.focusQualityScore)/100",
            subtitle: "Weighted by activity, breaks, wellness, and interruptions",
            icon: "checkmark.seal.fill"
          )
          DashboardInsightCard(
            title: "Idle minutes",
            value: "\(viewModel.idleMinutes)m",
            subtitle: "Within selected range",
            icon: "pause.circle"
          )
          DashboardInsightCard(
            title: "Interruptions",
            value: "\(viewModel.interruptionsCount)",
            subtitle: "Idle spikes above threshold",
            icon: "waveform.path.ecg"
          )
          DashboardInsightCard(
            title: "Skipped breaks",
            value: "\(viewModel.skippedBreakCount)",
            subtitle: "Breaks dismissed before completion",
            icon: "forward.end"
          )
        }
      }

      section(title: "Forecast & Wellness Mix", subtitle: "Forward-looking guidance") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
          DashboardMessageCard(
            title: "Goal forecast",
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
      return "Per-work-block app activity and session windows"
    case .week:
      return "Most active apps across the last 7 days"
    case .month:
      return "Most active apps across the last 30 days"
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
    clearDataStatusMessage =
      "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app usage)."
    viewModel.load(context: modelContext)
  }
}

private enum StyleGuide {
  static let goalLine = Color.orange.opacity(0.9)
}
