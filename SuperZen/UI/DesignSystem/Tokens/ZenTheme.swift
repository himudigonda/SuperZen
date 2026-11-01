import SwiftUI

nonisolated enum ZenColorRole: CaseIterable, Sendable {
  case canvas
  case canvasGlowTop
  case canvasGlowBottom
  case surfaceTop
  case surfaceBottom
  case surfaceStroke
  case surfaceHighlight
  case controlStroke
  case divider
  case shadow
  case textPrimary
  case textSecondary
  case textTertiary
  case accent
  case accentSecondary
  case accentTertiary
  case onAccent
  case success
  case warning
  case danger
  case info
  case overlayText
  case overlayTextSecondary
  case overlaySurface
  case overlayStroke
  case overlayScrim

  nonisolated enum Category: Sendable {
    case base
    case surface
    case stroke
    case shadow
    case text
    case accent
  }

  var category: Category {
    switch self {
    case .surfaceTop, .surfaceBottom: return .surface
    case .surfaceStroke, .surfaceHighlight, .controlStroke, .divider: return .stroke
    case .shadow: return .shadow
    case .textPrimary, .textSecondary, .textTertiary: return .text
    case .accent, .accentSecondary, .accentTertiary: return .accent
    default: return .base
    }
  }
}

nonisolated enum AccentPalette: String, CaseIterable, Identifiable, Sendable {
  case ocean = "Ocean"
  case emerald = "Emerald"
  case sunset = "Sunset"
  case violet = "Violet"
  case mono = "Mono"

  init(storedValue: String?) {
    self = storedValue.flatMap(Self.init(rawValue:)) ?? .ocean
  }

  var id: String { rawValue }

  var primary: ZenColorPair {
    switch self {
    case .ocean: return ZenColorPair(light: ZenRGBA(rgb: 0x007AFF), dark: ZenRGBA(rgb: 0x0A84FF))
    case .emerald:
      return ZenColorPair(light: ZenRGBA(rgb: 0x00975F), dark: ZenRGBA(rgb: 0x00A86B))
    case .sunset: return ZenColorPair(light: ZenRGBA(rgb: 0xD9541E), dark: ZenRGBA(rgb: 0xFF6B35))
    case .violet: return ZenColorPair(light: ZenRGBA(rgb: 0x7A5CFA), dark: ZenRGBA(rgb: 0x8B6CFB))
    case .mono: return ZenColorPair(light: ZenRGBA(rgb: 0x4B5563), dark: ZenRGBA(rgb: 0x9CA3AF))
    }
  }

  var secondary: ZenColorPair {
    switch self {
    case .ocean: return ZenColorPair(ZenRGBA(rgb: 0x22D3EE))
    case .emerald: return ZenColorPair(ZenRGBA(rgb: 0x43CEA2))
    case .sunset: return ZenColorPair(ZenRGBA(rgb: 0xF7B267))
    case .violet: return ZenColorPair(ZenRGBA(rgb: 0xA78BFA))
    case .mono: return ZenColorPair(ZenRGBA(rgb: 0x6B7280))
    }
  }

  var tertiary: ZenColorPair {
    switch self {
    case .ocean: return ZenColorPair(ZenRGBA(rgb: 0x7DD3FC))
    case .emerald: return ZenColorPair(ZenRGBA(rgb: 0x7AF6D4))
    case .sunset: return ZenColorPair(ZenRGBA(rgb: 0xFFD38A))
    case .violet: return ZenColorPair(ZenRGBA(rgb: 0xC4B5FD))
    case .mono: return ZenColorPair(ZenRGBA(rgb: 0xD1D5DB))
    }
  }

  var previewColors: [Color] {
    [primary.light.color, secondary.light.color, tertiary.light.color]
  }
}

nonisolated enum ContrastProfile: String, CaseIterable, Identifiable, Sendable {
  case soft = "Soft"
  case balanced = "Balanced"
  case high = "High"

  init(storedValue: String?) {
    self = storedValue.flatMap(Self.init(rawValue:)) ?? .balanced
  }

  var id: String { rawValue }

  var surfaceScale: Double {
    switch self {
    case .soft: return 0.85
    case .balanced: return 1
    case .high: return 1.3
    }
  }

  var strokeScale: Double {
    switch self {
    case .soft: return 0.75
    case .balanced: return 1
    case .high: return 1.45
    }
  }

  var shadowScale: Double {
    switch self {
    case .soft: return 0.7
    case .balanced: return 1
    case .high: return 1.35
    }
  }

  func escalated(systemIncreasedContrast: Bool) -> ContrastProfile {
    systemIncreasedContrast ? .high : self
  }
}

nonisolated enum ZenColorTokens {
  static func pair(for role: ZenColorRole) -> ZenColorPair {
    switch role {
    case .canvas:
      return ZenColorPair(
        light: ZenRGBA(red: 0.94, green: 0.95, blue: 0.98),
        dark: ZenRGBA(red: 0.07, green: 0.10, blue: 0.13))
    case .canvasGlowTop:
      return ZenColorPair(
        light: ZenRGBA.white.withAlpha(0.74), dark: ZenRGBA(rgb: 0x162431, alpha: 0.7))
    case .canvasGlowBottom:
      return ZenColorPair(
        light: ZenRGBA(rgb: 0xDEE7F4, alpha: 0.7), dark: ZenRGBA(rgb: 0x0B1117, alpha: 0.48))
    case .surfaceTop:
      return ZenColorPair(
        light: ZenRGBA.white.withAlpha(0.52),
        dark: ZenRGBA(red: 0.22, green: 0.31, blue: 0.38, alpha: 0.34))
    case .surfaceBottom:
      return ZenColorPair(
        light: ZenRGBA(red: 0.87, green: 0.91, blue: 0.97, alpha: 0.42),
        dark: ZenRGBA(red: 0.12, green: 0.17, blue: 0.22, alpha: 0.2))
    case .surfaceStroke:
      return ZenColorPair(
        light: ZenRGBA(red: 0.62, green: 0.68, blue: 0.77, alpha: 0.46),
        dark: ZenRGBA(red: 0.57, green: 0.65, blue: 0.74, alpha: 0.34))
    case .surfaceHighlight:
      return ZenColorPair(light: ZenRGBA.white.withAlpha(0.62), dark: ZenRGBA.white.withAlpha(0.16))
    case .controlStroke:
      return ZenColorPair(
        light: ZenRGBA(red: 0.58, green: 0.65, blue: 0.75, alpha: 0.42),
        dark: ZenRGBA(red: 0.58, green: 0.66, blue: 0.75, alpha: 0.3))
    case .divider:
      return ZenColorPair(
        light: ZenRGBA(red: 0.6, green: 0.66, blue: 0.75, alpha: 0.34),
        dark: ZenRGBA(red: 0.62, green: 0.7, blue: 0.8, alpha: 0.22))
    case .shadow:
      return ZenColorPair(
        light: ZenRGBA(red: 0.18, green: 0.24, blue: 0.33, alpha: 0.12),
        dark: ZenRGBA.black.withAlpha(0.3))
    case .textPrimary:
      return ZenColorPair(
        light: ZenRGBA(red: 0.09, green: 0.11, blue: 0.14, alpha: 0.96),
        dark: ZenRGBA(red: 0.93, green: 0.95, blue: 0.98, alpha: 0.98))
    case .textSecondary:
      return ZenColorPair(
        light: ZenRGBA(red: 0.29, green: 0.33, blue: 0.40, alpha: 0.88),
        dark: ZenRGBA(red: 0.70, green: 0.75, blue: 0.82, alpha: 0.9))
    case .textTertiary:
      return ZenColorPair(
        light: ZenRGBA(red: 0.30, green: 0.35, blue: 0.43, alpha: 0.9),
        dark: ZenRGBA(red: 0.62, green: 0.69, blue: 0.77, alpha: 0.9))
    case .accent:
      return AccentPalette.ocean.primary
    case .accentSecondary:
      return AccentPalette.ocean.secondary
    case .accentTertiary:
      return AccentPalette.ocean.tertiary
    case .onAccent:
      return ZenColorPair(.white)
    case .success:
      return ZenColorPair(light: ZenRGBA(rgb: 0x1F8A3B), dark: ZenRGBA(rgb: 0x30D158))
    case .warning:
      return ZenColorPair(light: ZenRGBA(rgb: 0xB25F00), dark: ZenRGBA(rgb: 0xFF9F0A))
    case .danger:
      return ZenColorPair(light: ZenRGBA(rgb: 0xD70015), dark: ZenRGBA(rgb: 0xFF453A))
    case .info:
      return ZenColorPair(light: ZenRGBA(rgb: 0x0062CC), dark: ZenRGBA(rgb: 0x409CFF))
    case .overlayText:
      return ZenColorPair(.white)
    case .overlayTextSecondary:
      return ZenColorPair(ZenRGBA.white.withAlpha(0.7))
    case .overlaySurface:
      return ZenColorPair(ZenRGBA(red: 0.1, green: 0.1, blue: 0.13, alpha: 0.96))
    case .overlayStroke:
      return ZenColorPair(ZenRGBA.white.withAlpha(0.15))
    case .overlayScrim:
      return ZenColorPair(ZenRGBA.black.withAlpha(0.2))
    }
  }
}

nonisolated struct ZenTheme: Hashable, Sendable {
  var accent: AccentPalette
  var contrast: ContrastProfile

  static let standard = ZenTheme(accent: .ocean, contrast: .balanced)

  func rgba(_ role: ZenColorRole, scheme: ColorScheme) -> ZenRGBA {
    switch role.category {
    case .accent:
      return accentPair(for: role).resolve(scheme)
    case .surface:
      return ZenColorTokens.pair(for: role).resolve(scheme).scalingAlpha(by: contrast.surfaceScale)
    case .stroke:
      return ZenColorTokens.pair(for: role).resolve(scheme).scalingAlpha(by: contrast.strokeScale)
    case .shadow:
      return ZenColorTokens.pair(for: role).resolve(scheme).scalingAlpha(by: contrast.shadowScale)
    case .text:
      let value = ZenColorTokens.pair(for: role).resolve(scheme)
      return contrast == .high ? value.withAlpha(1) : value
    case .base:
      return ZenColorTokens.pair(for: role).resolve(scheme)
    }
  }

  func color(_ role: ZenColorRole, scheme: ColorScheme) -> Color {
    rgba(role, scheme: scheme).color
  }

  private func accentPair(for role: ZenColorRole) -> ZenColorPair {
    switch role {
    case .accentSecondary: return accent.secondary
    case .accentTertiary: return accent.tertiary
    default: return accent.primary
    }
  }
}

nonisolated private struct ZenThemeKey: EnvironmentKey {
  static let defaultValue = ZenTheme.standard
}

extension EnvironmentValues {
  nonisolated var zenTheme: ZenTheme {
    get { self[ZenThemeKey.self] }
    set { self[ZenThemeKey.self] = newValue }
  }
}

nonisolated struct ZenColor: ShapeStyle {
  let role: ZenColorRole

  func resolve(in environment: EnvironmentValues) -> Color {
    environment.zenTheme.color(role, scheme: environment.colorScheme)
  }

  static let canvas = ZenColor(role: .canvas)
  static let surfaceStroke = ZenColor(role: .surfaceStroke)
  static let controlStroke = ZenColor(role: .controlStroke)
  static let divider = ZenColor(role: .divider)
  static let textPrimary = ZenColor(role: .textPrimary)
  static let textSecondary = ZenColor(role: .textSecondary)
  static let textTertiary = ZenColor(role: .textTertiary)
  static let accent = ZenColor(role: .accent)
  static let accentSecondary = ZenColor(role: .accentSecondary)
  static let onAccent = ZenColor(role: .onAccent)
  static let success = ZenColor(role: .success)
  static let warning = ZenColor(role: .warning)
  static let danger = ZenColor(role: .danger)
  static let info = ZenColor(role: .info)
  static let overlayText = ZenColor(role: .overlayText)
  static let overlayTextSecondary = ZenColor(role: .overlayTextSecondary)
  static let overlaySurface = ZenColor(role: .overlaySurface)
  static let overlayStroke = ZenColor(role: .overlayStroke)
  static let overlayScrim = ZenColor(role: .overlayScrim)
}

nonisolated struct ZenGradient: ShapeStyle {
  let roles: [ZenColorRole]
  var startPoint: UnitPoint = .topLeading
  var endPoint: UnitPoint = .bottomTrailing

  func resolve(in environment: EnvironmentValues) -> LinearGradient {
    LinearGradient(
      colors: roles.map { environment.zenTheme.color($0, scheme: environment.colorScheme) },
      startPoint: startPoint,
      endPoint: endPoint
    )
  }

  static let accent = ZenGradient(roles: [.accent, .accentSecondary])
  static let surface = ZenGradient(roles: [.surfaceTop, .surfaceBottom])
}

private struct ZenThemeProvider: ViewModifier {
  @AppStorage(SettingKey.uiAccentPalette) private var accentRaw = SettingsCatalog
    .accentPaletteDefault
  @AppStorage(SettingKey.uiContrastProfile) private var contrastRaw = SettingsCatalog
    .contrastProfileDefault
  @Environment(\.colorSchemeContrast) private var systemContrast

  func body(content: Content) -> some View {
    content
      .tint(ZenColor.accent)
      .environment(\.zenTheme, theme)
  }

  private var theme: ZenTheme {
    ZenTheme(
      accent: AccentPalette(storedValue: accentRaw),
      contrast: ContrastProfile(storedValue: contrastRaw)
        .escalated(systemIncreasedContrast: systemContrast == .increased)
    )
  }
}

extension View {
  func zenThemed() -> some View {
    modifier(ZenThemeProvider())
  }
}
