import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var stateManager: StateManager
  @StateObject private var viewModel = DashboardViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // 1. CRITICAL STATUS: The Ocular Load
      VStack(alignment: .leading, spacing: 8) {
        Text("Ocular Load").font(.headline).foregroundColor(Theme.textSectionHeader)
        HStack(alignment: .bottom, spacing: 12) {
          Text("\(viewModel.currentEyeLoadMinutes)")
            .font(.system(size: 64, weight: .black, design: .rounded))
          Text("Minutes focused").font(.title3).foregroundColor(Theme.textSecondary).padding(
            .bottom, 12)
          Spacer()
          // Verifiable Indicator
          StatusBadge(
            text: viewModel.currentEyeLoadMinutes > 20 ? "High Strain" : "Rested",
            color: viewModel.currentEyeLoadMinutes > 20 ? .orange : .green
          )
        }
        .padding(24)
        .background(Theme.cardBG)
        .cornerRadius(20)
      }

      // 2. RAW COMPLIANCE: No percentages, just counts
      VStack(alignment: .leading, spacing: 12) {
        Text("Physical Reminders").font(.headline).foregroundColor(Theme.textSectionHeader)
        HStack(spacing: 16) {
          ForEach(viewModel.wellnessSummary) { metric in
            VStack(alignment: .leading, spacing: 8) {
              Label(metric.name, systemImage: metric.icon).font(.caption).bold()
              Text("\(metric.completed)/\(metric.totalPrompted)")
                .font(.system(size: 24, weight: .bold))
              Text("Completed").font(.caption2).foregroundColor(Theme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBG)
            .cornerRadius(16)
          }
        }
      }

      // 3. PERFORMANCE TRUTH: Streak and Density
      HStack(spacing: 20) {
        DataMetricStrip(
          title: "Longest Session", value: "\(viewModel.longestFocusStreakMinutes)m", icon: "timer")
        DataMetricStrip(
          title: "Focus Density", value: String(format: "%.0f%%", viewModel.focusDensity * 100),
          icon: "brain")
      }

      // 4. VERIFIABLE HISTORY
      VStack(alignment: .leading, spacing: 12) {
        Text("Hourly Active Minutes").font(.headline).foregroundColor(Theme.textSectionHeader)
        Chart {
          ForEach(0..<24, id: \.self) { hour in
            BarMark(
              x: .value("Hour", hour),
              y: .value("Minutes", viewModel.hourlyFocus[hour, default: 0])
            )
            .foregroundStyle(.blue.gradient)
          }
        }
        .frame(height: 150)
        .padding()
        .background(Theme.cardBG)
        .cornerRadius(16)
      }
    }
    .onAppear { viewModel.refresh(context: modelContext, stateManager: stateManager) }
  }
}

// Minimalist Fact-Based Components
struct StatusBadge: View {
  let text: String
  let color: Color
  var body: some View {
    Text(text).font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
      .background(color.opacity(0.2)).foregroundColor(color).clipShape(Capsule())
  }
}

struct DataMetricStrip: View {
  let title: String
  let value: String
  let icon: String
  var body: some View {
    HStack {
      Image(systemName: icon).foregroundColor(.blue)
      Text(title).font(.subheadline).foregroundColor(Theme.textSecondary)
      Spacer()
      Text(value).font(.headline).bold()
    }
    .padding()
    .background(Theme.cardBG)
    .cornerRadius(12)
  }
}
