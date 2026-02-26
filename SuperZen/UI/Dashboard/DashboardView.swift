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
        .frame(width: 180)
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
          title: "Break completion",
          completed: viewModel.breakCompleted,
          total: viewModel.breakTotal,
          icon: "figure.mind.and.body"
        )
        DashboardRatioCard(
          title: "Wellness completion",
          completed: viewModel.wellnessCompleted,
          total: viewModel.wellnessTotal,
          icon: "heart.text.square"
        )
      }

      VStack(alignment: .leading, spacing: 12) {
        Text(viewModel.chartTitle)
          .font(.headline)
          .foregroundStyle(.secondary)
        Chart(viewModel.chartPoints) { point in
          BarMark(
            x: .value("Bucket", point.label),
            y: .value("Minutes", point.minutes)
          )
          .foregroundStyle(Theme.accent.gradient)
          .cornerRadius(3)
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
    .onAppear {
      viewModel.refresh(context: modelContext)
    }
    .onChange(of: viewModel.selectedRange) { _, _ in
      viewModel.refresh(context: modelContext)
    }
  }
}
