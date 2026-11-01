import SuperZenCore
import SwiftUI

struct WellnessOverlayView: View {
  let type: AppStatus.WellnessType
  @AppStorage(SettingKey.dimScreenWellness) var dimScreenWellness = true

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

  private static func localizedAffirmation(_ raw: String) -> String {
    String(
      localized: String.LocalizationValue(raw), comment: "Wellness overlay affirmation sentence")
  }

  var body: some View {
    ZStack {
      ZenBackgroundView(atmosphereColors: ZenPalette.wellnessAtmosphere(type))
      if dimScreenWellness {
        Rectangle().fill(ZenColor.overlayScrim).ignoresSafeArea()
      }

      VStack(spacing: ZenSpacing.xxl) {
        Text(ZenPalette.wellnessEmoji(type))
          .font(ZenFont.overlayEmoji)
          .accessibilityHidden(true)

        if type == .affirmation {
          Text(affirmationText)
            .font(ZenFont.overlayStatement)
            .foregroundStyle(ZenColor.overlayText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 80)
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        } else {
          Text(type.overlayTitle)
            .font(ZenFont.overlayTitle)
            .foregroundStyle(ZenColor.overlayText)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      affirmationText = Self.localizedAffirmation(
        Self.affirmations.randomElement() ?? Self.affirmations[0])
    }
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }
}
