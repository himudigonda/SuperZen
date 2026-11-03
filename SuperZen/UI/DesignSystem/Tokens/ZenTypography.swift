import AppKit
import CoreText
import SwiftUI

nonisolated enum ZenFontFace: String, CaseIterable, Sendable {
  case regular = "GoogleSans17pt-Regular"
  case medium = "GoogleSans17pt-Medium"
  case bold = "GoogleSans17pt-Bold"
}

nonisolated enum ZenFontRegistry {
  private static let registered: Bool = {
    let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
    let fonts = urls.filter { $0.lastPathComponent.hasPrefix("GoogleSans") }
    fonts.forEach { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, nil) }
    return !fonts.isEmpty
  }()

  @discardableResult
  static func register() -> Bool { registered }
}

nonisolated enum ZenFont {
  private static func face(_ face: ZenFontFace, _ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
    Font.custom(face.rawValue, size: size, relativeTo: style)
  }

  static let displayLarge = face(.regular, 57, relativeTo: .largeTitle)
  static let displayMedium = face(.regular, 45, relativeTo: .largeTitle)
  static let displaySmall = face(.regular, 36, relativeTo: .largeTitle)
  static let headlineLarge = face(.regular, 32, relativeTo: .largeTitle)
  static let headlineMedium = face(.regular, 28, relativeTo: .title)
  static let headlineSmall = face(.regular, 24, relativeTo: .title)
  static let titleLarge = face(.regular, 22, relativeTo: .title2)
  static let titleMedium = face(.medium, 16, relativeTo: .headline)
  static let titleSmall = face(.medium, 14, relativeTo: .subheadline)
  static let bodyLarge = face(.regular, 16, relativeTo: .body)
  static let bodyMedium = face(.regular, 14, relativeTo: .body)
  static let bodySmall = face(.regular, 12, relativeTo: .caption)
  static let labelLarge = face(.medium, 14, relativeTo: .callout)
  static let labelMedium = face(.medium, 12, relativeTo: .caption)
  static let labelSmall = face(.medium, 11, relativeTo: .caption2)

  static let headlineEmphasized = face(.medium, 28, relativeTo: .title)
  static let titleEmphasized = face(.medium, 22, relativeTo: .title2)
  static let statValue = face(.medium, 24, relativeTo: .title).monospacedDigit()
  static let ringTimer = face(.medium, 28, relativeTo: .title).monospacedDigit()
  static let keycap = Font.system(.callout, design: .monospaced, weight: .medium)
  static let menuBarMetric = face(.medium, 11, relativeTo: .caption2).monospacedDigit()
  static let menuBarMetricInside = face(.bold, 10, relativeTo: .caption2).monospacedDigit()

  static let iconSmall = Font.system(size: 14, weight: .medium)
  static let iconMedium = Font.system(size: 18, weight: .regular)
  static let iconLarge = Font.system(size: 24, weight: .regular)
  static let heroIcon = Font.system(size: 44, weight: .medium)
  static let tileEmoji = Font.system(size: 48)
  static let overlayEmoji = Font.system(size: 100)

  static let onboardingTitle = face(.regular, 32, relativeTo: .largeTitle)
  static let onboardingNumeral = face(.medium, 64, relativeTo: .largeTitle).monospacedDigit()
  static let alertTimer = face(.medium, 48, relativeTo: .largeTitle).monospacedDigit()
  static let overlayStatement = face(.regular, 40, relativeTo: .largeTitle)
  static let overlayTitle = face(.medium, 57, relativeTo: .largeTitle)
  static let overlayHero = face(.medium, 64, relativeTo: .largeTitle)
  static let overlayTimer = face(.medium, 140, relativeTo: .largeTitle).monospacedDigit()
  static let overlayAction = face(.medium, 16, relativeTo: .headline)
}
