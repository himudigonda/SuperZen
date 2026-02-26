import SwiftUI

struct VitalityMetricCard: View {
  let title: String
  let icon: String
  let value: Double
  let primaryText: String
  let subtitle: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.bold))
        .foregroundColor(Theme.textSecondary)

      HStack(alignment: .bottom, spacing: 10) {
        Text(primaryText)
          .font(.system(size: 24, weight: .black, design: .rounded))
          .foregroundColor(Theme.textPrimary)
        Spacer()
      }

      Text(subtitle)
        .font(.caption)
        .foregroundColor(Theme.textSecondary)

      ProgressView(value: value)
        .tint(color)
        .scaleEffect(x: 1, y: 1.8, anchor: .center)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.cardBG)
    .cornerRadius(14)
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
  }
}

struct BioScoreRing: View {
  let score: Int
  let label: String

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.08), lineWidth: 14)

      Circle()
        .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100.0)
        .stroke(
          AngularGradient(colors: [.red, .orange, .yellow, .green], center: .center),
          style: StrokeStyle(lineWidth: 14, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))

      VStack(spacing: 2) {
        Text("\(score)")
          .font(.system(size: 40, weight: .black, design: .rounded))
          .foregroundColor(Theme.textPrimary)
        Text(label)
          .font(.caption2.weight(.bold))
          .foregroundColor(Theme.textSecondary)
      }
    }
    .frame(width: 140, height: 140)
  }
}

struct FocusHeatmapView: View {
  let data: [Int: Double]
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 12)

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(0..<24, id: \.self) { hour in
          let intensity = data[hour, default: 0]
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.cyan.opacity(0.15 + (0.85 * intensity)))
            .frame(height: 28)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .overlay(
              Text(shortHour(hour))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
            )
        }
      }
      HStack {
        Text("Low")
        Spacer()
        Text("Peak Intensity")
      }
      .font(.caption2)
      .foregroundColor(Theme.textSecondary)
    }
  }

  private func shortHour(_ hour: Int) -> String {
    if hour == 0 { return "12a" }
    if hour < 12 { return "\(hour)a" }
    if hour == 12 { return "12p" }
    return "\(hour - 12)p"
  }
}
