import Foundation
import SuperZenCore
import SwiftUI

@MainActor
enum BreakTipPicker {
  private static var lastID: String?

  static func pick(for kind: BreakKind, defaults: UserDefaults = .standard) -> BreakTip? {
    guard defaults.bool(forKey: SettingKey.breakTipsEnabled) else { return nil }
    let tip = BreakContent.next(for: kind, excluding: lastID)
    lastID = tip.id
    return tip
  }
}

struct BreakTipView: View {
  let tip: BreakTip

  var body: some View {
    Text(LocalizedStringKey(tip.englishText))
      .font(ZenFont.bodyLarge)
      .foregroundStyle(ZenColor.overlayTextSecondary)
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: ZenOverlayMetrics.progressWidth)
      .accessibilityLabel(Text(LocalizedStringKey(tip.englishText)))
  }
}
