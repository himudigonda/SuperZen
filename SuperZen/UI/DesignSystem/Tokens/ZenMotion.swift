import SwiftUI

nonisolated enum ZenMotion: CaseIterable, Sendable {
  case quick
  case standard
  case emphasized
  case gentle
  case ambient

  var duration: Double {
    switch self {
    case .quick: return 0.15
    case .standard: return 0.25
    case .emphasized: return 0.35
    case .gentle: return 0.4
    case .ambient: return 1.0
    }
  }

  var movesContent: Bool {
    switch self {
    case .quick, .standard, .emphasized: return true
    case .gentle, .ambient: return false
    }
  }

  static let reducedCrossfadeDuration = 0.12

  func animation(reduceMotion: Bool) -> Animation? {
    if reduceMotion {
      return movesContent ? nil : .easeInOut(duration: Self.reducedCrossfadeDuration)
    }
    switch self {
    case .quick: return .timingCurve(0.2, 0, 0, 1, duration: duration)
    case .standard: return .timingCurve(0.2, 0, 0, 1, duration: duration)
    case .emphasized: return .spring(response: duration, dampingFraction: 0.8)
    case .gentle: return .timingCurve(0.05, 0.7, 0.1, 1, duration: duration)
    case .ambient: return .easeInOut(duration: duration)
    }
  }
}

enum ZenTransition {
  static func slide(insertion: Edge, removal: Edge, reduceMotion: Bool) -> AnyTransition {
    guard !reduceMotion else { return .opacity }
    return .asymmetric(
      insertion: .opacity.combined(with: .move(edge: insertion)),
      removal: .opacity.combined(with: .move(edge: removal))
    )
  }
}

private struct ZenAnimationModifier<Value: Equatable>: ViewModifier {
  let motion: ZenMotion
  let value: Value
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
  }
}

extension View {
  func zenAnimation<Value: Equatable>(_ motion: ZenMotion, value: Value) -> some View {
    modifier(ZenAnimationModifier(motion: motion, value: value))
  }
}

@discardableResult
func withZenAnimation<Result>(
  _ motion: ZenMotion, reduceMotion: Bool, _ body: () throws -> Result
) rethrows -> Result {
  try withAnimation(motion.animation(reduceMotion: reduceMotion), body)
}
