import SwiftUI

struct DashboardStatCard: View {
  let title: String
  let value: String
  let icon: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(Theme.textPrimary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}

struct DashboardRatioCard: View {
  let title: String
  let completed: Int
  let total: Int
  let icon: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
      Text("\(completed)/\(total)")
        .font(.title3.weight(.bold))
        .foregroundStyle(Theme.textPrimary)
      Text("Completed")
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}

struct DashboardGoalCard: View {
  let title: String
  let progress: Double
  let valueText: String
  let targetText: String
  let tint: Color

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      Text(valueText)
        .font(.headline.weight(.bold))
        .foregroundStyle(Theme.textPrimary)
      ProgressView(value: max(0, min(1, progress)))
        .tint(tint)
      Text("Target \(targetText)")
        .font(.caption2.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}

struct DashboardInsightCard: View {
  let title: String
  let value: String
  let subtitle: String
  let icon: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(Theme.textPrimary)
      Text(subtitle)
        .font(.caption2.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}

struct DashboardMessageCard: View {
  let title: String
  let message: String
  let icon: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      Text(message)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.textPrimary)
        .lineSpacing(2)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}

struct WellnessBreakdownCard: View {
  let stats: [DashboardViewModel.WellnessTypeStat]

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    VStack(alignment: .leading, spacing: 10) {
      Label("Wellness completion by type", systemImage: "list.bullet.clipboard")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)

      ForEach(stats) { item in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(item.label)
              .font(.caption.weight(.semibold))
              .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(item.completed)/\(item.total) • \(item.completionRate)%")
              .font(.caption2.weight(.medium))
              .foregroundStyle(Theme.textSecondary)
          }
          ProgressView(value: Double(item.completionRate) / 100.0)
            .tint(Theme.accent)
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}
