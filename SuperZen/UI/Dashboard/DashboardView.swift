import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var viewModel = DashboardViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text("Insights")
          .font(.title2.weight(.bold))
        Spacer()
        Picker("Range", selection: $viewModel.selectedRange) {
          ForEach(DashboardViewModel.Range.allCases) { range in
            Text(range.rawValue).tag(range)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 250)
      }

      HStack(spacing: 14) {
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
      }

      HStack(spacing: 14) {
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

      HStack(spacing: 14) {
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
      }

      HStack(spacing: 14) {
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

      VStack(alignment: .leading, spacing: 12) {
        Text(viewModel.chartTitle)
          .font(.headline)
          .foregroundStyle(.secondary)
        Chart {
          ForEach(viewModel.chartPoints) { point in
            BarMark(
              x: .value("Bucket", point.label),
              y: .value("Minutes", point.minutes)
            )
            .foregroundStyle(Theme.accent.gradient)
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
        .frame(height: 220)
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
    }
    .onAppear {
      viewModel.refresh(context: modelContext)
    }
    .onChange(of: viewModel.selectedRange) { _, _ in
      viewModel.refresh(context: modelContext)
    }
  }

  private var trendText: String {
    let delta = viewModel.trendDeltaPercent
    if delta > 0 { return "+\(delta)%" }
    return "\(delta)%"
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
}

private enum StyleGuide {
  static let goalLine = Color.orange.opacity(0.9)
}
