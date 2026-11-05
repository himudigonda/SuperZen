import AppKit
import Foundation
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
struct ColorTokenTests {
  private let schemes: [ColorScheme] = [.light, .dark]

  @Test(arguments: [
    ("0A84FF", ZenRGBA(rgb: 0x0A84FF)),
    ("#0a84ff", ZenRGBA(rgb: 0x0A84FF)),
    ("FFF", ZenRGBA(red: 1, green: 1, blue: 1)),
    ("FF000080", ZenRGBA(rgb: 0xFF0000, alpha: 128.0 / 255)),
  ])
  func hexParsesValidInput(_ input: String, expected: ZenRGBA) {
    #expect(ZenRGBA(hex: input) == expected)
  }

  @Test(arguments: ["", "#", "12", "GGGGGG", "12345", "+12345", "0A84FF00FF"])
  func hexRejectsInvalidInputInsteadOfFallingBack(_ input: String) {
    #expect(ZenRGBA(hex: input) == nil)
  }

  @Test func contrastRatioMatchesWCAGReferencePoints() {
    #expect(abs(ZenRGBA.black.contrastRatio(against: .white) - 21) < 0.01)
    #expect(abs(ZenRGBA.white.contrastRatio(against: .white) - 1) < 0.0001)
  }

  private static let surfaces: [ZenColorRole] = [
    .surface, .surfaceDim, .surfaceBright, .surfaceContainerLowest, .surfaceContainerLow, .surfaceContainer,
    .surfaceContainerHigh, .surfaceContainerHighest,
  ]

  private static let pairs: [(ZenColorRole, ZenColorRole)] = [
    (.onPrimary, .primary), (.onPrimaryContainer, .primaryContainer), (.onSecondary, .secondary),
    (.onSecondaryContainer, .secondaryContainer), (.onTertiary, .tertiary),
    (.onTertiaryContainer, .tertiaryContainer), (.onError, .error), (.onErrorContainer, .errorContainer),
    (.onSuccess, .success), (.onSuccessContainer, .successContainer), (.onWarning, .warning),
    (.onWarningContainer, .warningContainer), (.onInfo, .info), (.onInfoContainer, .infoContainer),
    (.inverseOnSurface, .inverseSurface),
  ]

  @Test(arguments: ContrastProfile.allCases)
  func bodyTextMeetsWCAGAAOnEverySurfaceInBothSchemes(_ profile: ContrastProfile) {
    for palette in AccentPalette.allCases {
      let theme = ZenTheme(accent: palette, contrast: profile)
      for scheme in schemes {
        for role in Self.surfaces {
          let surface = theme.rgba(role, scheme: scheme)
          #expect(theme.rgba(.onSurface, scheme: scheme).contrastRatio(against: surface) >= 7)
          #expect(theme.rgba(.onSurfaceVariant, scheme: scheme).contrastRatio(against: surface) >= 4.5)
        }
      }
    }
  }

  @Test(arguments: ContrastProfile.allCases)
  func everyOnRoleMeetsWCAGAAOnItsContainer(_ profile: ContrastProfile) {
    for palette in AccentPalette.allCases {
      let theme = ZenTheme(accent: palette, contrast: profile)
      for scheme in schemes {
        for (on, container) in Self.pairs {
          let ratio = theme.rgba(on, scheme: scheme).contrastRatio(against: theme.rgba(container, scheme: scheme))
          #expect(ratio >= 4.5, "\(on) on \(container), \(palette) \(profile) \(scheme): \(ratio)")
        }
      }
    }
  }

  @Test(arguments: AccentPalette.allCases)
  func primaryMeetsNonTextContrastInBothSchemes(_ palette: AccentPalette) {
    let theme = ZenTheme(accent: palette, contrast: .balanced)
    for scheme in schemes {
      let canvas = theme.rgba(.surface, scheme: scheme)
      #expect(theme.rgba(.primary, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test(arguments: [ZenColorRole.success, .warning, .error, .info])
  func statusColorsMeetNonTextContrastInBothSchemes(_ role: ZenColorRole) {
    for scheme in schemes {
      let canvas = ZenTheme.standard.rgba(.surface, scheme: scheme)
      #expect(ZenTheme.standard.rgba(role, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test func lightAndDarkResolveDifferentlyForAdaptiveRoles() {
    for role in [ZenColorRole.surface, .onSurface, .onSurfaceVariant, .surfaceContainer, .primary] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) != ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func overlayRolesIgnoreTheColorScheme() {
    for role in [ZenColorRole.overlayText, .overlaySurface, .overlayStroke, .overlayScrim] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) == ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func contrastProfilesOrderOutlineAndTextStrength() {
    for scheme in schemes {
      func ratios(_ role: ZenColorRole) -> [Double] {
        ContrastProfile.allCases.map {
          let theme = ZenTheme(accent: .ocean, contrast: $0)
          return theme.rgba(role, scheme: scheme).contrastRatio(against: theme.rgba(.surface, scheme: scheme))
        }
      }
      for role in [ZenColorRole.outlineVariant, .outline] {
        let values = ratios(role)
        #expect(values == values.sorted())
        #expect(Set(values).count == values.count)
      }
      let text = ratios(.onSurfaceVariant)
      #expect(text[2] > text[1])
    }
  }

  @Test func surfaceContainersStepMonotonicallyFromTheCanvas() {
    let order: [ZenColorRole] = [
      .surfaceContainerLow, .surfaceContainer, .surfaceContainerHigh, .surfaceContainerHighest,
    ]
    let light = order.map { ZenTheme.standard.rgba($0, scheme: .light).relativeLuminance }
    let dark = order.map { ZenTheme.standard.rgba($0, scheme: .dark).relativeLuminance }
    #expect(light == light.sorted(by: >))
    #expect(dark == dark.sorted())
  }

  @Test(arguments: [0.0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 100])
  func tonalPaletteHitsTheRequestedLuminance(_ tone: Double) {
    for palette in AccentPalette.allCases.map(\.palettes.primary) + [ZenCorePalettes.error, ZenCorePalettes.warning] {
      let luminance = palette.tone(tone).relativeLuminance
      #expect(abs(luminance - ZenTonalPalette.luminance(forTone: tone)) < 0.004)
    }
  }

  @Test func toneDistanceGuaranteesContrast() {
    let palette = AccentPalette.sunset.palettes.primary
    #expect(palette.tone(40).contrastRatio(against: palette.tone(90)) >= 4.5)
    #expect(palette.tone(50).contrastRatio(against: palette.tone(90)) >= 3)
  }

  @Test func seedConversionRoundTripsThroughOKLCH() {
    let seed = ZenRGBA(rgb: 0x007AFF)
    let result = ZenOKLCH(seed).clampedToGamut
    #expect(abs(result.red - seed.red) < 0.01)
    #expect(abs(result.green - seed.green) < 0.01)
    #expect(abs(result.blue - seed.blue) < 0.01)
  }

  @Test func systemIncreasedContrastEscalatesToHigh() {
    for profile in ContrastProfile.allCases {
      #expect(profile.escalated(systemIncreasedContrast: true) == .high)
      #expect(profile.escalated(systemIncreasedContrast: false) == profile)
    }
  }

  @Test func accentPaletteRetintsWithoutChangingStatusOrOverlayRoles() {
    let ocean = ZenTheme(accent: .ocean, contrast: .balanced)
    let sunset = ZenTheme(accent: .sunset, contrast: .balanced)
    #expect(ocean.rgba(.primary, scheme: .light) != sunset.rgba(.primary, scheme: .light))
    for role in [ZenColorRole.error, .success, .warning, .info, .overlayText, .overlaySurface] {
      #expect(ocean.rgba(role, scheme: .light) == sunset.rgba(role, scheme: .light))
    }
  }

  @Test func storedSettingsTokensMapToEveryEnumCase() {
    #expect(SettingsCatalog.accentPalettes.compactMap(AccentPalette.init(rawValue:)) == AccentPalette.allCases)
    #expect(
      SettingsCatalog.contrastProfiles.compactMap(ContrastProfile.init(rawValue:))
        == ContrastProfile.allCases)
    #expect(AccentPalette(storedValue: SettingsCatalog.accentPaletteDefault) == .ocean)
    #expect(ContrastProfile(storedValue: SettingsCatalog.contrastProfileDefault) == .balanced)
    #expect(AccentPalette(storedValue: "Neon") == .ocean)
    #expect(ContrastProfile(storedValue: nil) == .balanced)
  }
}
