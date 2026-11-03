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
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let lgIncreased: CGFloat = 20
  static let xl: CGFloat = 28
  static let xlIncreased: CGFloat = 32
  static let xxl: CGFloat = 48

  static let scale: [CGFloat] = [xs, sm, md, lg, lgIncreased, xl, xlIncreased, xxl]
}

nonisolated enum ZenStateLayer {
  static let hover = 0.08
  static let focus = 0.10
  static let press = 0.10
  static let disabledContainer = 0.12
  static let disabledContent = 0.38

  static func opacity(isHovered: Bool, isPressed: Bool) -> Double {
    if isPressed { return press }
    return isHovered ? hover : 0
  }
}

nonisolated enum ZenElevation: CaseIterable, Sendable {
  case level0
  case level1
  case level2
  case level3
  case level4
  case level5

  var radius: CGFloat {
    switch self {
    case .level0: return 0
    case .level1: return 3
    case .level2: return 6
    case .level3: return 12
    case .level4: return 18
    case .level5: return 28
    }
  }

  var yOffset: CGFloat {
    switch self {
    case .level0: return 0
    case .level1: return 1
    case .level2: return 2
    case .level3: return 4
    case .level4: return 6
    case .level5: return 8
    }
  }

  var shadowStrength: Double {
    switch self {
    case .level0: return 0
    case .level1: return 0.5
    case .level2: return 0.65
    case .level3: return 0.8
    case .level4: return 0.9
    case .level5: return 1
    }
  }
}

private struct ZenElevationModifier: ViewModifier {
  let level: ZenElevation
  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.compositingGroup().shadow(
      color: theme.rgba(.shadow, scheme: colorScheme)
        .scalingAlpha(by: level.shadowStrength * theme.contrast.shadowScale).color,
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
