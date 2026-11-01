import SwiftUI

nonisolated struct ZenRGBA: Hashable, Sendable {
  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = Self.unit(red)
    self.green = Self.unit(green)
    self.blue = Self.unit(blue)
    self.alpha = Self.unit(alpha)
  }

  init(rgb: UInt32, alpha: Double = 1) {
    self.init(
      red: Double((rgb >> 16) & 0xFF) / 255,
      green: Double((rgb >> 8) & 0xFF) / 255,
      blue: Double(rgb & 0xFF) / 255,
      alpha: alpha
    )
  }

  init?(hex: String) {
    var digits = Substring(hex.trimmingCharacters(in: .whitespacesAndNewlines))
    if digits.hasPrefix("#") { digits = digits.dropFirst() }
    guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit),
      let value = UInt64(digits, radix: 16)
    else { return nil }

    switch digits.count {
    case 3:
      self.init(
        red: Double((value >> 8) & 0xF) * 17 / 255,
        green: Double((value >> 4) & 0xF) * 17 / 255,
        blue: Double(value & 0xF) * 17 / 255
      )
    case 6:
      self.init(rgb: UInt32(value))
    default:
      self.init(rgb: UInt32(value >> 8), alpha: Double(value & 0xFF) / 255)
    }
  }

  static let white = ZenRGBA(red: 1, green: 1, blue: 1)
  static let black = ZenRGBA(red: 0, green: 0, blue: 0)

  var color: Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

  func withAlpha(_ value: Double) -> ZenRGBA {
    ZenRGBA(red: red, green: green, blue: blue, alpha: value)
  }

  func scalingAlpha(by factor: Double) -> ZenRGBA {
    withAlpha(alpha * factor)
  }

  func composited(over background: ZenRGBA) -> ZenRGBA {
    let base = background.alpha < 1 ? background.composited(over: .white) : background
    return ZenRGBA(
      red: red * alpha + base.red * (1 - alpha),
      green: green * alpha + base.green * (1 - alpha),
      blue: blue * alpha + base.blue * (1 - alpha)
    )
  }

  var relativeLuminance: Double {
    0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
  }

  func contrastRatio(against background: ZenRGBA) -> Double {
    let opaqueBackground = background.alpha < 1 ? background.composited(over: .white) : background
    let foreground = composited(over: opaqueBackground)
    let lighter = max(foreground.relativeLuminance, opaqueBackground.relativeLuminance)
    let darker = min(foreground.relativeLuminance, opaqueBackground.relativeLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private static func unit(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private static func linear(_ channel: Double) -> Double {
    channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
  }
}

nonisolated struct ZenColorPair: Hashable, Sendable {
  let light: ZenRGBA
  let dark: ZenRGBA

  init(light: ZenRGBA, dark: ZenRGBA) {
    self.light = light
    self.dark = dark
  }

  init(_ both: ZenRGBA) {
    self.init(light: both, dark: both)
  }

  func resolve(_ scheme: ColorScheme) -> ZenRGBA {
    scheme == .dark ? dark : light
  }
}
