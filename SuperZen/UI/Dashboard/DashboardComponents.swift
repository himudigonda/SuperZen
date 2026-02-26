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
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(.primary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: shape)
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(.quaternary, lineWidth: 1))
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
        .foregroundStyle(.secondary)
      Text("\(completed)/\(total)")
        .font(.title3.weight(.bold))
      Text("Completed")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: shape)
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(.quaternary, lineWidth: 1))
  }
}
