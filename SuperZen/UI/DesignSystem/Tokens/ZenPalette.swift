import SuperZenCore
import SwiftUI

nonisolated enum ZenPalette {
  private static func palette(_ difficulty: BreakDifficulty) -> ZenTonalPalette {
    switch difficulty {
    case .casual: return ZenTonalPalette(hue: 255, chroma: 0.15)
    case .balanced: return ZenTonalPalette(hue: 62, chroma: 0.14)
    case .hardcore: return ZenTonalPalette(hue: 27, chroma: 0.19)
    }
  }

  private static func palette(_ type: AppStatus.WellnessType) -> ZenTonalPalette {
    switch type {
    case .posture: return ZenTonalPalette(hue: 10, chroma: 0.17)
    case .blink: return ZenTonalPalette(hue: 255, chroma: 0.15)
    case .water: return ZenTonalPalette(hue: 225, chroma: 0.12)
    case .affirmation: return ZenTonalPalette(hue: 90, chroma: 0.14)
    }
  }

  static func difficultyColors(_ difficulty: BreakDifficulty) -> [ZenRGBA] {
    let tonal = palette(difficulty)
    return [tonal.tone(25), tonal.tone(40)]
  }

  static func difficultyGradient(_ difficulty: BreakDifficulty) -> LinearGradient {
    LinearGradient(
      colors: difficultyColors(difficulty).map(\.color),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static func breakAccent(_ difficulty: BreakDifficulty, canSkip: Bool) -> Color {
    let source = difficulty == .balanced && canSkip ? BreakDifficulty.casual : difficulty
    return palette(source).tone(80).color
  }

  static func breakAtmosphere(_ difficulty: BreakDifficulty, canSkip: Bool) -> [Color] {
    let source = difficulty == .balanced && canSkip ? BreakDifficulty.casual : difficulty
    return atmosphere(palette(source))
  }

  static func wellnessTint(_ type: AppStatus.WellnessType) -> Color {
    palette(type).tone(80).color
  }

  static func wellnessContainer(_ type: AppStatus.WellnessType, scheme: ColorScheme) -> Color {
    palette(type).tone(scheme == .dark ? 30 : 90).color
  }

  static func wellnessOnContainer(_ type: AppStatus.WellnessType, scheme: ColorScheme) -> Color {
    palette(type).tone(scheme == .dark ? 90 : 30).color
  }

  static func wellnessAtmosphere(_ type: AppStatus.WellnessType) -> [Color] {
    atmosphere(palette(type))
  }

  static func wellnessSymbol(_ type: AppStatus.WellnessType) -> String {
    switch type {
    case .posture: return "figure.mind.and.body"
    case .blink: return "eye.fill"
    case .water: return "drop.fill"
    case .affirmation: return "bolt.fill"
    }
  }

  static let fallbackBackground = difficultyGradient(.casual)

  private static func atmosphere(_ tonal: ZenTonalPalette) -> [Color] {
    let deep = tonal.tone(8).color
    let dark = tonal.tone(20).color
    let mid = tonal.tone(32).color
    let peak = tonal.tone(42).color
    return [deep, mid, deep, dark, peak, dark, deep, mid, deep]
  }
}
