import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var stateManager: StateManager
  @StateObject private var viewModel = DashboardViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      headerSection
      chartsRow
      statusCard
    }
    .background(Color.clear)
    .onAppear { viewModel.refresh(context: modelContext) }
    .onChange(of: stateManager.status) { _, _ in
      viewModel.refresh(context: modelContext)
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Overview")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundColor(Theme.textPrimary)

      Text("You've focused for \(Int(viewModel.totalToday / 60)) minutes today.")
        .font(.title3)
        .foregroundColor(Theme.textSecondary)

      HStack(spacing: 20) {
        vitalsChip(
          icon: "checkmark.seal.fill",
          value: "\(viewModel.breaksTakenToday)",
          label: "Breaks Taken",
          color: .green
        )
        vitalsChip(
          icon: "forward.fill",
          value: "\(viewModel.breaksSkippedToday)",
          label: "Skipped",
          color: .orange
        )
      }
      .padding(.top, 4)
    }
  }

  private func vitalsChip(icon: String, value: String, label: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .foregroundColor(color)
      Text("\(value) \(label)")
        .font(.subheadline)
        .foregroundColor(Theme.textSecondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(color.opacity(0.1))
    .cornerRadius(8)
  }

  // MARK: - Charts Row

  private var chartsRow: some View {
    HStack(alignment: .top, spacing: 16) {
      focusChartCard
        .frame(maxWidth: .infinity)
      complianceCard
        .frame(width: 200)
    }
  }

  private var focusChartCard: some View {
    ZenCard {
      VStack(alignment: .leading, spacing: 16) {
        Label("Weekly Intensity", systemImage: "chart.bar.fill")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        if viewModel.weeklyFocus.isEmpty {
          Text("No focus data yet.")
            .foregroundColor(Theme.textSecondary)
            .frame(height: 200)
        } else {
          Chart(viewModel.weeklyFocus) { item in
            BarMark(
              x: .value("Day", item.date, unit: .day),
              y: .value("Minutes", item.seconds / 60)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
          }
          .frame(height: 200)
          .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
              AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                .foregroundStyle(Theme.textSecondary)
            }
          }
          .chartYAxis {
            AxisMarks { value in
              AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)m")
                .foregroundStyle(Theme.textSecondary)
            }
          }
        }
      }
      .padding(20)
    }
  }

  private var complianceCard: some View {
    ZenCard {
      VStack(alignment: .leading, spacing: 16) {
        Label("Compliance", systemImage: "chart.pie.fill")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        let total = viewModel.breaksTakenToday + viewModel.breaksSkippedToday
        if total == 0 {
          Text("None")
            .foregroundColor(Theme.textSecondary)
            .frame(height: 160)
        } else {
          Chart(viewModel.compliance) { item in
            SectorMark(
              angle: .value("Count", item.count),
              innerRadius: .ratio(0.58),
              angularInset: 2
            )
            .foregroundStyle(by: .value("Status", item.status))
            .cornerRadius(4)
          }
          .chartForegroundStyleScale([
            "Taken": Color.green,
            // swiftlint:disable:next trailing_comma
            "Skipped": Color.orange,
          ])
          .frame(height: 160)
          .chartLegend(.automatic)
        }
      }
      .padding(20)
    }
  }

  // MARK: - Status Card

  private var statusCard: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Current Session")
          .font(.subheadline)
          .foregroundColor(Theme.textSecondary)
        Text(stateManager.status.description)
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
      }

      Spacer()

      Text(formatTime(stateManager.timeRemaining))
        .font(.system(.title, design: .monospaced))
        .bold()
        .monospacedDigit()
        .foregroundColor(Theme.textPrimary)
    }
    .padding(16)
    .background(
      stateManager.status == .active
        ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.05)
    )
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
  }

  // MARK: - Helpers

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
