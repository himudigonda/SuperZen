import SwiftUI

nonisolated enum ZenOverlayMetrics {
  static let contentMaxWidth: CGFloat = 840
  static let progressWidth: CGFloat = 460
  static let progressHeight: CGFloat = 6
  static let actionMinWidth: CGFloat = 196
  static let actionHeight: CGFloat = 56
  static let symbolBadge: CGFloat = 176
  static let disabledOpacity = 0.7
  static let referenceSize = CGSize(width: 1440, height: 900)
  static let maxContentScale: CGFloat = 1.75

  static func contentScale(for size: CGSize) -> CGFloat {
    guard size.width > 0, size.height > 0 else { return 1 }
    let fit = min(size.width / referenceSize.width, size.height / referenceSize.height)
    return min(maxContentScale, max(1, fit))
  }
}

nonisolated enum ZenScrimBackdrop: Sendable {
  case atmosphere
  case photograph

  func role(highContrast: Bool) -> ZenColorRole {
    switch (self, highContrast) {
    case (.atmosphere, false): return .overlayScrimSoft
    case (.photograph, false): return .overlayScrimStrong
    case (.atmosphere, true): return .overlayScrimStrong
    case (.photograph, true): return .overlayScrimMax
    }
  }
}
