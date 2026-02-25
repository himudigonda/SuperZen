import SwiftUI

struct WellnessOverlayView: View {
  let type: AppStatus.WellnessType

  var body: some View {
    ZStack {
      // 1. Full Screen Background
      VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
        .ignoresSafeArea()

      // 2. Atmosphere
      atmosphereGradient
        .ignoresSafeArea()
        .opacity(0.5)

      // 3. Centered Content
      VStack(spacing: 40) {
        Text(emoji)
          .font(.system(size: 120))

        Text(title)
          .font(.system(size: 60, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ViewBuilder
  private var atmosphereGradient: some View {
    if #available(macOS 15.0, *) {
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.5, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1],
        ],
        colors: atmosphereColors)
    } else {
      LinearGradient(colors: [atmosphereColors[4], .black], startPoint: .top, endPoint: .bottom)
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
