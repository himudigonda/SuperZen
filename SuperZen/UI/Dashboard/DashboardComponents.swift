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
