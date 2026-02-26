import SwiftUI

struct WellnessOverlayView: View {
  let type: AppStatus.WellnessType

  // Picked once when the view appears so it stays stable for the full display.
  @State private var affirmationText: String = ""

  private static let affirmations: [String] = [
    "You are making real progress. Keep going.",
    "Deep focus creates extraordinary results.",
    "Every minute of effort compounds over time.",
    "You have what it takes to crush this.",
    "Small wins lead to big victories. Stay the course.",
    "Your best work is ahead of you.",
    "Focused minds achieve great things.",
    "You are stronger than any distraction.",
    "Progress, not perfection. Keep moving forward.",
    "Your effort today builds your success tomorrow.",
    "Believe in the work. Believe in yourself.",
    "Stay patient. Stay consistent. Win.",
    "You showed up. That already makes you exceptional.",
    "One focused session at a time. You've got this.",
    "The work you do in quiet moments defines you.",
  ]

  var body: some View {
    ZStack {
      ZenBackgroundView(atmosphereColors: atmosphereColors)

      VStack(spacing: 32) {
        Text(emoji).font(.system(size: 100))

        if type == .affirmation {
          VStack(spacing: 16) {
            Text(affirmationText)
              .font(.system(size: 38, weight: .bold, design: .rounded))
              .foregroundColor(.white)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 80)
              .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
          }
        } else {
          Text(title)
            .font(.system(size: 60, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      affirmationText = Self.affirmations.randomElement() ?? Self.affirmations[0]
    }
  }

  private var atmosphereColors: [Color] {
    switch type {
    case .posture:
      return [.black, .pink, .black, .orange, .pink, .black, .black, .purple, .black]
    case .blink:
      return [.black, .blue, .black, .cyan, .blue, .black, .black, .indigo, .black]
    case .water:
      return [.black, .cyan, .black, .blue, .cyan, .black, .black, .teal, .black]
    case .affirmation:
      return [.black, .yellow, .black, .orange, .yellow, .black, .black, .green, .black]
    }
  }

  private var emoji: String {
    switch type {
    case .posture: return "🧘‍♂️"
    case .blink: return "👁️"
    case .water: return "💧"
    case .affirmation: return "⚡️"
    }
  }

  private var title: String {
    switch type {
    case .posture: return "Sit Up Straight"
    case .blink: return "Blink Your Eyes"
    case .water: return "Drink Water"
    case .affirmation: return ""
    }
  }
}
