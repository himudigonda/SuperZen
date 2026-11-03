import SwiftUI

nonisolated enum ZenSpacing {
  static let xxs: CGFloat = 4
  static let xs: CGFloat = 8
  static let sm: CGFloat = 12
  static let md: CGFloat = 16
  static let lg: CGFloat = 20
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
  static let xxxl: CGFloat = 48

  static let scale: [CGFloat] = [xxs, xs, sm, md, lg, xl, xxl, xxxl]
}

nonisolated enum ZenRadius {
  static let xs: CGFloat = 6
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let xl: CGFloat = 20

  static let scale: [CGFloat] = [xs, sm, md, lg, xl]
}

nonisolated enum ZenElevation: CaseIterable, Sendable {
  case flat
  case raised
  case floating
  case overlay

  var radius: CGFloat {
    switch self {
    case .flat: return 0
    case .raised: return 6
    case .floating: return 14
    case .overlay: return 32
    }
  }

  var yOffset: CGFloat {
    switch self {
    case .flat: return 0
    case .raised: return 2
    case .floating: return 6
    case .overlay: return 12
    }
  }

  var shadowStrength: Double {
    switch self {
    case .flat: return 0
    case .raised: return 1
    case .floating: return 1.4
    case .overlay: return 3
    }
  }
}

private struct ZenElevationModifier: ViewModifier {
  let level: ZenElevation
  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.shadow(
      color: theme.rgba(.shadow, scheme: colorScheme)
        .scalingAlpha(by: level.shadowStrength).color,
      radius: level.radius,
      x: 0,
      y: level.yOffset
    )
  }
}

extension View {
  func zenElevation(_ level: ZenElevation) -> some View {
    modifier(ZenElevationModifier(level: level))
  }
}
