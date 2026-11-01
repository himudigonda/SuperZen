import SuperZenCore
import SwiftUI

struct WellnessOverlayView: View {
  let type: AppStatus.WellnessType
  @AppStorage(SettingKey.dimScreenWellness) var dimScreenWellness = true

  // Picked once when the view appears so it stays stable for the full display.
  @State private var affirmationText: String = ""

  /// Canonical English affirmation text, also used as the String Catalog lookup key for
  /// each sentence — `String.LocalizationValue(_:)` resolves a runtime string against the
  /// catalog just like a compile-time literal would.
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

  private static func localizedAffirmation(_ raw: String) -> String {
    String(
      localized: String.LocalizationValue(raw), comment: "Wellness overlay affirmation sentence")
  }

  var body: some View {
    ZStack {
      ZenBackgroundView(atmosphereColors: atmosphereColors)
      if dimScreenWellness {
        Color.black.opacity(0.2).ignoresSafeArea()
      }

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
      affirmationText = Self.localizedAffirmation(
        Self.affirmations.randomElement() ?? Self.affirmations[0])
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
    case .posture:
      return String(
        localized: "Sit Up Straight", comment: "Wellness overlay title: posture reminder")
    case .blink:
      return String(localized: "Blink Your Eyes", comment: "Wellness overlay title: blink reminder")
    case .water:
      return String(localized: "Drink Water", comment: "Wellness overlay title: hydration reminder")
    case .affirmation: return ""
    }
  }
}
