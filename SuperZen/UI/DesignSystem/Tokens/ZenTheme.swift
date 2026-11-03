import SwiftUI
import os

nonisolated enum ZenColorRole: CaseIterable, Sendable {
  case primary, onPrimary, primaryContainer, onPrimaryContainer, inversePrimary
  case primaryFixed, primaryFixedDim, onPrimaryFixed
  case secondary, onSecondary, secondaryContainer, onSecondaryContainer
  case tertiary, onTertiary, tertiaryContainer, onTertiaryContainer
  case error, onError, errorContainer, onErrorContainer
  case success, onSuccess, successContainer, onSuccessContainer
  case warning, onWarning, warningContainer, onWarningContainer
  case info, onInfo, infoContainer, onInfoContainer
  case surface, surfaceDim, surfaceBright
  case surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh
  case surfaceContainerHighest
  case onSurface, onSurfaceVariant, outline, outlineVariant
  case inverseSurface, inverseOnSurface, scrim, shadow
  case overlayText, overlayTextSecondary, overlaySurface, overlayStroke, overlayScrim
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

  var seed: ZenRGBA {
    switch self {
    case .ocean: return ZenRGBA(rgb: 0x007AFF)
    case .emerald: return ZenRGBA(rgb: 0x00975F)
    case .sunset: return ZenRGBA(rgb: 0xD9541E)
    case .violet: return ZenRGBA(rgb: 0x7A5CFA)
    case .mono: return ZenRGBA(rgb: 0x4B5563)
    }
  }

  var palettes: ZenCorePalettes {
    let base = ZenTonalPalette(seed: seed)
    if self == .mono {
      return ZenCorePalettes(
        primary: base.shifted(chroma: 0.014),
        secondary: base.shifted(chroma: 0.008),
        tertiary: base.shifted(chroma: 0.012),
        neutral: base.shifted(chroma: 0.002),
        neutralVariant: base.shifted(chroma: 0.004))
    }
    return ZenCorePalettes(
      primary: base.shifted(chroma: min(base.chroma, 0.17)),
      secondary: base.shifted(chroma: 0.04),
      tertiary: base.shifted(hue: 60, chroma: 0.085),
      neutral: base.shifted(chroma: 0.006),
      neutralVariant: base.shifted(chroma: 0.016))
  }

  var previewColors: [Color] {
    let palettes = palettes
    return [palettes.primary.tone(40).color, palettes.primary.tone(80).color, palettes.tertiary.tone(70).color]
  }
}

nonisolated struct ZenCorePalettes: Hashable, Sendable {
  let primary: ZenTonalPalette
  let secondary: ZenTonalPalette
  let tertiary: ZenTonalPalette
  let neutral: ZenTonalPalette
  let neutralVariant: ZenTonalPalette

  static let error = ZenTonalPalette(hue: 27, chroma: 0.19)
  static let success = ZenTonalPalette(hue: 148, chroma: 0.14)
  static let warning = ZenTonalPalette(hue: 72, chroma: 0.13)
  static let info = ZenTonalPalette(hue: 240, chroma: 0.11)
}

nonisolated enum ContrastProfile: String, CaseIterable, Identifiable, Sendable {
  case soft = "Soft"
  case balanced = "Balanced"
  case high = "High"

  init(storedValue: String?) {
    self = storedValue.flatMap(Self.init(rawValue:)) ?? .balanced
  }

  var id: String { rawValue }

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

nonisolated private enum ZenToneSource: Sendable {
  case primary, secondary, tertiary, neutral, neutralVariant
  case error, success, warning, info

  func palette(in core: ZenCorePalettes) -> ZenTonalPalette {
    switch self {
    case .primary: return core.primary
    case .secondary: return core.secondary
    case .tertiary: return core.tertiary
    case .neutral: return core.neutral
    case .neutralVariant: return core.neutralVariant
    case .error: return ZenCorePalettes.error
    case .success: return ZenCorePalettes.success
    case .warning: return ZenCorePalettes.warning
    case .info: return ZenCorePalettes.info
    }
  }
}

nonisolated private struct ZenToneSpec: Sendable {
  let source: ZenToneSource
  let light: Double
  let dark: Double
  var softLight: Double?
  var softDark: Double?
  var highLight: Double?
  var highDark: Double?

  func tone(scheme: ColorScheme, contrast: ContrastProfile) -> Double {
    let isDark = scheme == .dark
    switch contrast {
    case .soft: return (isDark ? softDark : softLight) ?? (isDark ? dark : light)
    case .balanced: return isDark ? dark : light
    case .high: return (isDark ? highDark : highLight) ?? (isDark ? dark : light)
    }
  }
}

nonisolated private enum ZenColorRoleSpec {
  static func accentGroup(_ source: ZenToneSource, part: Int) -> ZenToneSpec {
    switch part {
    case 0: return ZenToneSpec(source: source, light: 40, dark: 80, highLight: 25, highDark: 90)
    case 1: return ZenToneSpec(source: source, light: 100, dark: 20, highLight: 100, highDark: 0)
    case 2: return ZenToneSpec(source: source, light: 90, dark: 30, highLight: 30, highDark: 85)
    default: return ZenToneSpec(source: source, light: 30, dark: 90, highLight: 100, highDark: 0)
    }
  }

  static func spec(for role: ZenColorRole) -> ZenToneSpec? {
    switch role {
    case .primary: return accentGroup(.primary, part: 0)
    case .onPrimary: return accentGroup(.primary, part: 1)
    case .primaryContainer: return accentGroup(.primary, part: 2)
    case .onPrimaryContainer: return accentGroup(.primary, part: 3)
    case .inversePrimary: return ZenToneSpec(source: .primary, light: 80, dark: 40)
    case .primaryFixed: return ZenToneSpec(source: .primary, light: 90, dark: 90)
    case .primaryFixedDim: return ZenToneSpec(source: .primary, light: 80, dark: 80)
    case .onPrimaryFixed: return ZenToneSpec(source: .primary, light: 10, dark: 10)
    case .secondary: return accentGroup(.secondary, part: 0)
    case .onSecondary: return accentGroup(.secondary, part: 1)
    case .secondaryContainer: return accentGroup(.secondary, part: 2)
    case .onSecondaryContainer: return accentGroup(.secondary, part: 3)
    case .tertiary: return accentGroup(.tertiary, part: 0)
    case .onTertiary: return accentGroup(.tertiary, part: 1)
    case .tertiaryContainer: return accentGroup(.tertiary, part: 2)
    case .onTertiaryContainer: return accentGroup(.tertiary, part: 3)
    case .error: return accentGroup(.error, part: 0)
    case .onError: return accentGroup(.error, part: 1)
    case .errorContainer: return accentGroup(.error, part: 2)
    case .onErrorContainer: return accentGroup(.error, part: 3)
    case .success: return accentGroup(.success, part: 0)
    case .onSuccess: return accentGroup(.success, part: 1)
    case .successContainer: return accentGroup(.success, part: 2)
    case .onSuccessContainer: return accentGroup(.success, part: 3)
    case .warning: return accentGroup(.warning, part: 0)
    case .onWarning: return accentGroup(.warning, part: 1)
    case .warningContainer: return accentGroup(.warning, part: 2)
    case .onWarningContainer: return accentGroup(.warning, part: 3)
    case .info: return accentGroup(.info, part: 0)
    case .onInfo: return accentGroup(.info, part: 1)
    case .infoContainer: return accentGroup(.info, part: 2)
    case .onInfoContainer: return accentGroup(.info, part: 3)
    case .surface: return ZenToneSpec(source: .neutral, light: 98, dark: 6)
    case .surfaceDim: return ZenToneSpec(source: .neutral, light: 87, dark: 6)
    case .surfaceBright: return ZenToneSpec(source: .neutral, light: 98, dark: 24)
    case .surfaceContainerLowest: return ZenToneSpec(source: .neutral, light: 100, dark: 4)
    case .surfaceContainerLow: return ZenToneSpec(source: .neutral, light: 96, dark: 10)
    case .surfaceContainer: return ZenToneSpec(source: .neutral, light: 94, dark: 12)
    case .surfaceContainerHigh: return ZenToneSpec(source: .neutral, light: 92, dark: 17)
    case .surfaceContainerHighest: return ZenToneSpec(source: .neutral, light: 90, dark: 22)
    case .onSurface: return ZenToneSpec(source: .neutral, light: 10, dark: 90, highLight: 0, highDark: 100)
    case .onSurfaceVariant:
      return ZenToneSpec(source: .neutralVariant, light: 30, dark: 80, highLight: 15, highDark: 95)
    case .outline:
      return ZenToneSpec(
        source: .neutralVariant, light: 50, dark: 60, softLight: 55, softDark: 55, highLight: 25, highDark: 85)
    case .outlineVariant:
      return ZenToneSpec(
        source: .neutralVariant, light: 80, dark: 30, softLight: 85, softDark: 25, highLight: 45, highDark: 70)
    case .inverseSurface: return ZenToneSpec(source: .neutral, light: 20, dark: 90)
    case .inverseOnSurface: return ZenToneSpec(source: .neutral, light: 95, dark: 20)
    case .scrim, .shadow, .overlayText, .overlayTextSecondary, .overlaySurface, .overlayStroke, .overlayScrim:
      return nil
    }
  }

  static func fixed(_ role: ZenColorRole) -> ZenRGBA {
    switch role {
    case .scrim: return ZenRGBA.black.withAlpha(0.32)
    case .shadow: return ZenRGBA.black.withAlpha(0.3)
    case .overlayText: return .white
    case .overlayTextSecondary: return ZenRGBA.white.withAlpha(0.82)
    case .overlaySurface: return ZenRGBA(rgb: 0x1B1B1F, alpha: 0.96)
    case .overlayStroke: return ZenRGBA.white.withAlpha(0.2)
    case .overlayScrim: return ZenRGBA.black.withAlpha(0.32)
    default: return .black
    }
  }
}

nonisolated struct ZenTheme: Hashable, Sendable {
  var accent: AccentPalette
  var contrast: ContrastProfile

  static let standard = ZenTheme(accent: .ocean, contrast: .balanced)

  private struct CacheKey: Hashable, Sendable {
    let theme: ZenTheme
    let isDark: Bool
  }

  private static let cache = OSAllocatedUnfairLock(initialState: [CacheKey: [ZenColorRole: ZenRGBA]]())

  func rgba(_ role: ZenColorRole, scheme: ColorScheme) -> ZenRGBA {
    let key = CacheKey(theme: self, isDark: scheme == .dark)
    if let table = Self.cache.withLock({ $0[key] }) {
      return table[role] ?? .black
    }
    let table = buildTable(scheme: scheme)
    Self.cache.withLock { $0[key] = table }
    return table[role] ?? .black
  }

  func color(_ role: ZenColorRole, scheme: ColorScheme) -> Color {
    rgba(role, scheme: scheme).color
  }

  private func buildTable(scheme: ColorScheme) -> [ZenColorRole: ZenRGBA] {
    let core = accent.palettes
    var table: [ZenColorRole: ZenRGBA] = [:]
    for role in ZenColorRole.allCases {
      if let spec = ZenColorRoleSpec.spec(for: role) {
        table[role] = spec.source.palette(in: core).tone(spec.tone(scheme: scheme, contrast: contrast))
      } else {
        table[role] = ZenColorRoleSpec.fixed(role)
      }
    }
    return table
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

  static let primary = ZenColor(role: .primary)
  static let onPrimary = ZenColor(role: .onPrimary)
  static let primaryContainer = ZenColor(role: .primaryContainer)
  static let onPrimaryContainer = ZenColor(role: .onPrimaryContainer)
  static let inversePrimary = ZenColor(role: .inversePrimary)
  static let primaryFixed = ZenColor(role: .primaryFixed)
  static let primaryFixedDim = ZenColor(role: .primaryFixedDim)
  static let onPrimaryFixed = ZenColor(role: .onPrimaryFixed)
  static let secondary = ZenColor(role: .secondary)
  static let onSecondary = ZenColor(role: .onSecondary)
  static let secondaryContainer = ZenColor(role: .secondaryContainer)
  static let onSecondaryContainer = ZenColor(role: .onSecondaryContainer)
  static let tertiary = ZenColor(role: .tertiary)
  static let onTertiary = ZenColor(role: .onTertiary)
  static let tertiaryContainer = ZenColor(role: .tertiaryContainer)
  static let onTertiaryContainer = ZenColor(role: .onTertiaryContainer)
  static let error = ZenColor(role: .error)
  static let onError = ZenColor(role: .onError)
  static let errorContainer = ZenColor(role: .errorContainer)
  static let onErrorContainer = ZenColor(role: .onErrorContainer)
  static let success = ZenColor(role: .success)
  static let onSuccess = ZenColor(role: .onSuccess)
  static let successContainer = ZenColor(role: .successContainer)
  static let onSuccessContainer = ZenColor(role: .onSuccessContainer)
  static let warning = ZenColor(role: .warning)
  static let onWarning = ZenColor(role: .onWarning)
  static let warningContainer = ZenColor(role: .warningContainer)
  static let onWarningContainer = ZenColor(role: .onWarningContainer)
  static let info = ZenColor(role: .info)
  static let onInfo = ZenColor(role: .onInfo)
  static let infoContainer = ZenColor(role: .infoContainer)
  static let onInfoContainer = ZenColor(role: .onInfoContainer)
  static let surface = ZenColor(role: .surface)
  static let surfaceDim = ZenColor(role: .surfaceDim)
  static let surfaceBright = ZenColor(role: .surfaceBright)
  static let surfaceContainerLowest = ZenColor(role: .surfaceContainerLowest)
  static let surfaceContainerLow = ZenColor(role: .surfaceContainerLow)
  static let surfaceContainer = ZenColor(role: .surfaceContainer)
  static let surfaceContainerHigh = ZenColor(role: .surfaceContainerHigh)
  static let surfaceContainerHighest = ZenColor(role: .surfaceContainerHighest)
  static let onSurface = ZenColor(role: .onSurface)
  static let onSurfaceVariant = ZenColor(role: .onSurfaceVariant)
  static let outline = ZenColor(role: .outline)
  static let outlineVariant = ZenColor(role: .outlineVariant)
  static let inverseSurface = ZenColor(role: .inverseSurface)
  static let inverseOnSurface = ZenColor(role: .inverseOnSurface)
  static let scrim = ZenColor(role: .scrim)
  static let overlayText = ZenColor(role: .overlayText)
  static let overlayTextSecondary = ZenColor(role: .overlayTextSecondary)
  static let overlaySurface = ZenColor(role: .overlaySurface)
  static let overlayStroke = ZenColor(role: .overlayStroke)
  static let overlayScrim = ZenColor(role: .overlayScrim)
}

private struct ZenThemeProvider: ViewModifier {
  @AppStorage(SettingKey.uiAccentPalette) private var accentRaw = SettingsCatalog
    .accentPaletteDefault
  @AppStorage(SettingKey.uiContrastProfile) private var contrastRaw = SettingsCatalog
    .contrastProfileDefault
  @Environment(\.colorSchemeContrast) private var systemContrast

  func body(content: Content) -> some View {
    content
      .tint(ZenColor.primary)
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
