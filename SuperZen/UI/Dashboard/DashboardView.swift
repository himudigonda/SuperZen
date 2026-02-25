import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var stateManager: StateManager
  @StateObject private var viewModel = DashboardViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        headerSection
        chartsRow
        statusCard
      }
      .padding(32)
    }
    .background(Color(NSColor.windowBackgroundColor))
    .onAppear { viewModel.refresh(context: modelContext) }
    .onChange(of: stateManager.status) { _, _ in
      viewModel.refresh(context: modelContext)
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("SuperZen")
        .font(.system(size: 28, weight: .bold, design: .rounded))

      Text("You've focused for \(Int(viewModel.totalToday / 60)) minutes today.")
        .font(.title3)
        .foregroundColor(.secondary)

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
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(color.opacity(0.08))
    .cornerRadius(8)
  }

  // MARK: - Charts Row

  private var chartsRow: some View {
    HStack(alignment: .top, spacing: 20) {
      focusChartCard
        .frame(maxWidth: .infinity)
      complianceCard
        .frame(width: 200)
    }
  }

  private var focusChartCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Weekly Intensity", systemImage: "chart.bar.fill")
        .font(.headline)

      if viewModel.weeklyFocus.isEmpty {
        Text("No focus data yet.")
          .foregroundColor(.secondary)
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
          }
        }
        .chartYAxis {
          AxisMarks { value in
            AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)m")
          }
        }
      }
    }
    .padding(20)
    .background(Color.primary.opacity(0.04))
    .cornerRadius(16)
  }

  private var complianceCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Break Compliance", systemImage: "chart.pie.fill")
        .font(.headline)

      let total = viewModel.breaksTakenToday + viewModel.breaksSkippedToday
      if total == 0 {
        Text("No breaks logged yet.")
          .foregroundColor(.secondary)
          .frame(height: 150)
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
        .frame(width: 160, height: 160)
        .chartLegend(.automatic)
      }
    }
    .padding(20)
    .background(Color.primary.opacity(0.04))
    .cornerRadius(16)
  }

  // MARK: - Status Card

  private var statusCard: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Current Session")
          .font(.subheadline)
          .foregroundColor(.secondary)
        Text(stateManager.status.description)
          .font(.headline)
      }

      Spacer()

      Text(formatTime(stateManager.timeRemaining))
        .font(.system(.title, design: .monospaced))
        .bold()
        .monospacedDigit()
    }
    .padding(16)
    .background(
      stateManager.status == .active
        ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.05)
    )
    .cornerRadius(12)
  }

  // MARK: - Helpers

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
