import SwiftUI

struct WellnessOverlayView: View {
  let type: AppStatus.WellnessType

  var body: some View {
    ZStack {
      // Unified background engine — uses the same bg/blur setting as break screens
      ZenBackgroundView(atmosphereColors: atmosphereColors)

      VStack(spacing: 40) {
        Text(emoji).font(.system(size: 120))

        Text(title)
          .font(.system(size: 60, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var atmosphereColors: [Color] {
    switch type {
    case .posture: return [.black, .pink, .black, .orange, .pink, .black, .black, .purple, .black]
    case .blink: return [.black, .blue, .black, .cyan, .blue, .black, .black, .indigo, .black]
    case .water: return [.black, .cyan, .black, .blue, .cyan, .black, .black, .teal, .black]
    }
  }

  private var emoji: String {
    switch type {
    case .posture: return "🧘‍♂️"
    case .blink: return "👁️"
    case .water: return "💧"
    }
  }

  private var title: String {
    switch type {
    case .posture: return "Sit Up Straight"
    case .blink: return "Blink Your Eyes"
    case .water: return "Drink Water"
    }
  }
}
