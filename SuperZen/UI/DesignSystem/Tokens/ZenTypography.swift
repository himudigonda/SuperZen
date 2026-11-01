import SwiftUI

nonisolated enum ZenFont {
  static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
  static let title = Font.system(.title, design: .rounded, weight: .bold)
  static let title2 = Font.system(.title2, design: .rounded, weight: .bold)
  static let headline = Font.headline
  static let body = Font.body
  static let bodyEmphasized = Font.body.weight(.semibold)
  static let callout = Font.callout
  static let calloutEmphasized = Font.callout.weight(.semibold)
  static let subheadline = Font.subheadline
  static let subheadlineEmphasized = Font.subheadline.weight(.semibold)
  static let caption = Font.caption
  static let captionEmphasized = Font.caption.weight(.semibold)
  static let statValue = Font.system(.title2, design: .rounded, weight: .bold).monospacedDigit()
  static let keycap = Font.system(.callout, design: .monospaced, weight: .semibold)
  static let rowIcon = Font.system(.title3, weight: .regular)
  static let controlIcon = Font.system(.caption, weight: .bold)
  static let roundedLabel = Font.system(.callout, design: .rounded, weight: .bold)
  static let roundedCaption = Font.system(.subheadline, design: .rounded, weight: .medium)

  static let heroIcon = Font.system(size: 44, weight: .semibold)
  static let tileEmoji = Font.system(size: 48)
  static let alertTimer = Font.system(size: 48, weight: .bold, design: .rounded).monospacedDigit()
  static let overlayStatement = Font.system(size: 40, weight: .bold, design: .rounded)
  static let overlayTitle = Font.system(size: 60, weight: .bold, design: .rounded)
  static let overlayHero = Font.system(size: 64, weight: .bold, design: .rounded)
  static let overlayEmoji = Font.system(size: 100)
  static let overlayTimer = Font.system(size: 140, weight: .bold, design: .rounded)
    .monospacedDigit()
  static let overlayAction = Font.system(.title3, design: .rounded, weight: .bold)
}
