import SuperZenCore
import SwiftUI

enum ZenPalette {
  static func difficultyColors(_ difficulty: BreakDifficulty) -> [ZenRGBA] {
    switch difficulty {
    case .casual: return [ZenRGBA(rgb: 0x0D47A1), ZenRGBA(rgb: 0x00B8D4)]
    case .balanced: return [ZenRGBA(rgb: 0xFF8F00), ZenRGBA(rgb: 0xFFB300)]
    case .hardcore: return [ZenRGBA(rgb: 0xB71C1C), ZenRGBA(rgb: 0xD32F2F)]
    }
  }

  static func difficultyGradient(_ difficulty: BreakDifficulty) -> LinearGradient {
    LinearGradient(
      colors: difficultyColors(difficulty).map(\.color),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static func breakAccent(_ difficulty: BreakDifficulty, canSkip: Bool) -> Color {
    switch difficulty {
    case .casual: return ZenRGBA(rgb: 0x0A84FF).color
    case .balanced: return (canSkip ? ZenRGBA(rgb: 0x0A84FF) : ZenRGBA(rgb: 0xFFB300)).color
    case .hardcore: return ZenRGBA(rgb: 0xD32F2F).color
    }
  }

  static func breakAtmosphere(_ difficulty: BreakDifficulty, canSkip: Bool) -> [Color] {
    switch difficulty {
    case .casual:
      return atmosphere(0x0D47A1, 0x1976D2, 0x00B8D4, 0x01579B)
    case .balanced:
      return canSkip
        ? atmosphere(0x0D47A1, 0x1565C0, 0x0288D1, 0x01579B)
        : atmosphere(0xFF8F00, 0xFFB300, 0xE65100, 0xF57C00)
    case .hardcore:
      return atmosphere(0xB71C1C, 0xD32F2F, 0x000000, 0x880E4F)
    }
  }

  static func wellnessTint(_ type: AppStatus.WellnessType) -> Color {
    switch type {
    case .posture: return ZenRGBA(rgb: 0xFF375F).color
    case .blink: return ZenRGBA(rgb: 0x0A84FF).color
    case .water: return ZenRGBA(rgb: 0x32ADE6).color
    case .affirmation: return ZenRGBA(rgb: 0xFFCC00).color
    }
  }

  static func wellnessAtmosphere(_ type: AppStatus.WellnessType) -> [Color] {
    switch type {
    case .posture: return atmosphere(0xFF375F, 0xFF9500, 0xFF375F, 0xAF52DE)
    case .blink: return atmosphere(0x0A84FF, 0x32ADE6, 0x0A84FF, 0x5856D6)
    case .water: return atmosphere(0x32ADE6, 0x0A84FF, 0x32ADE6, 0x30B0C7)
    case .affirmation: return atmosphere(0xFFCC00, 0xFF9500, 0xFFCC00, 0x34C759)
    }
  }

  static func wellnessEmoji(_ type: AppStatus.WellnessType) -> String {
    switch type {
    case .posture: return "🧘"
    case .blink: return "👁️"
    case .water: return "💧"
    case .affirmation: return "⚡️"
    }
  }

  static let fallbackBackground = difficultyGradient(.casual)

  private static func atmosphere(
    _ top: UInt32, _ left: UInt32, _ center: UInt32, _ bottom: UInt32
  ) -> [Color] {
    let black = Color.black
    return [
      black, ZenRGBA(rgb: top).color, black,
      ZenRGBA(rgb: left).color, ZenRGBA(rgb: center).color, black,
      black, ZenRGBA(rgb: bottom).color, black,
    ]
  }
}
