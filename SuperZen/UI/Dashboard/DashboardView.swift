import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var stateManager: StateManager
  @StateObject private var viewModel = DashboardViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      heroSection
      vitalitySection
      focusDistributionSection
      weeklyTrendSection
      liveSessionStrip
    }
    .background(Color.clear)
    .onAppear { viewModel.refresh(context: modelContext) }
    .onChange(of: stateManager.status) { _, _ in
      viewModel.refresh(context: modelContext)
    }
  }

  // MARK: - Hero

  private var heroSection: some View {
    HStack(spacing: 24) {
      BioScoreRing(score: viewModel.bioScore, label: "Score")

      VStack(alignment: .leading, spacing: 8) {
        Text("Today Summary")
          .font(.title2.weight(.bold))
          .foregroundColor(Theme.textPrimary)

        Text(viewModel.summary)
          .font(.subheadline)
          .foregroundColor(Theme.textSecondary)
          .lineLimit(3)

        HStack(spacing: 18) {
          metricPill(
            icon: "brain.head.profile",
            text: "Focus \(viewModel.todayFocusMinutes)m")
          metricPill(
            icon: "pause.circle",
            text: "Idle \(viewModel.todayIdleMinutes)m")
          metricPill(
            icon: "checkmark.seal",
            text: "Breaks \(Int(viewModel.breakAdherence * 100))%")
          metricPill(
            icon: "exclamationmark.triangle",
            text: "Interruptions \(viewModel.todayInterruptions)")
        }
      }

      Spacer()
    }
    .padding(20)
    .background(Theme.cardBG.opacity(0.8))
    .cornerRadius(20)
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
  }

  private func metricPill(icon: String, text: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon).foregroundColor(.cyan)
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundColor(Theme.textSecondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.white.opacity(0.06))
    .cornerRadius(8)
  }

  // MARK: - Wellness Cadence

  private var vitalitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Wellness Reminders")
        .font(.headline)
        .foregroundColor(Theme.textSectionHeader)

      HStack(spacing: 14) {
        ForEach(viewModel.wellnessCadence) { metric in
          VitalityMetricCard(
            title: metric.title,
            icon: metric.icon,
            value: metric.progress,
            primaryText: "\(metric.shown)",
            subtitle: metric.targetMinutes == 0
              ? metric.status : "Target every \(metric.targetMinutes)m • \(metric.status)",
            color: metric.color
          )
        }
      }
    }
  }

  // MARK: - Focus Distribution

  private var focusDistributionSection: some View {
    let peak = viewModel.hourlyFocusToday.max { $0.value < $1.value }
    let peakHour = peak?.key
    let peakMinutes = Int((peak?.value ?? 0).rounded())
    let activeHours = viewModel.hourlyFocusToday.values.filter { $0 > 0 }.count

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Focus Distribution (Today)")
          .font(.headline)
          .foregroundColor(Theme.textSectionHeader)
        Spacer()
        Text(
          activeHours == 0
            ? "No activity yet" : "\(activeHours) active hour\(activeHours == 1 ? "" : "s")"
        )
        .font(.caption)
        .foregroundColor(Theme.textSecondary)
      }

      Chart(0..<24, id: \.self) { hour in
        BarMark(
          x: .value("Hour", hour),
          y: .value("Minutes", viewModel.hourlyFocusToday[hour, default: 0])
        )
        .foregroundStyle(
          LinearGradient(
            colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .cornerRadius(3)
      }
      .frame(height: 130)
      .chartXAxis {
        AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
          if let hour = value.as(Int.self) {
            AxisValueLabel(shortHour(hour))
              .foregroundStyle(Theme.textSecondary)
          }
        }
      }
      .chartYAxis {
        AxisMarks { value in
          AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)m")
            .foregroundStyle(Theme.textSecondary)
        }
      }
      .chartYScale(domain: 0...(max(10, (viewModel.hourlyFocusToday.values.max() ?? 0) + 10)))
      .chartPlotStyle { plot in
        plot
          .background(Color.white.opacity(0.01))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.white.opacity(0.04), lineWidth: 1)
          )
      }

      HStack(spacing: 12) {
        Text(
          peakHour != nil
            ? "Peak: \(shortHour(peakHour ?? 0)) (\(peakMinutes)m)"
            : "Peak: --"
        )
        .font(.caption)
        .foregroundColor(Theme.textSecondary)
        Spacer()
        Text("Total Focus: \(viewModel.todayFocusMinutes)m")
          .font(.caption)
          .foregroundColor(Theme.textSecondary)
      }
      .padding(14)
      .background(Theme.cardBG)
      .cornerRadius(16)
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
  }

  // MARK: - Weekly Trend

  private var weeklyTrendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Weekly Focus Trend")
        .font(.headline)
        .foregroundColor(Theme.textSectionHeader)

      Chart(viewModel.weeklyFocus) { point in
        BarMark(
          x: .value("Day", point.date, unit: .day),
          y: .value("Minutes", point.minutes)
        )
        .foregroundStyle(Color.accentColor.gradient)
        .cornerRadius(4)
      }
      .frame(height: 180)
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
      .padding(14)
      .background(Theme.cardBG)
      .cornerRadius(16)
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
  }

  // MARK: - Live Session

  private var liveSessionStrip: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Live Session State")
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
      stateManager.status == .active ? Color.cyan.opacity(0.16) : Color.white.opacity(0.05)
    )
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }

  private func shortHour(_ hour: Int) -> String {
    if hour == 0 { return "12a" }
    if hour < 12 { return "\(hour)a" }
    if hour == 12 { return "12p" }
    return "\(hour - 12)p"
  }
}
