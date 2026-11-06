public enum OverlayKind: CaseIterable, Hashable, Sendable {
  case breakScreen
  case wellness
  case nudge
  case alert
  case breakBanner

  public var coversScreens: Bool {
    self == .breakScreen || self == .wellness
  }

  public var isBreak: Bool {
    self == .breakScreen || self == .breakBanner
  }

  var displacedByLive: Set<OverlayKind> {
    switch self {
    case .breakScreen: return [.breakBanner, .wellness, .nudge, .alert]
    case .breakBanner: return [.breakScreen, .wellness, .nudge, .alert]
    case .wellness: return [.nudge, .alert]
    case .nudge, .alert: return []
    }
  }
}

public enum OverlaySource: Hashable, Sendable {
  case live
  case preview
}

public struct OverlayPresentation: Hashable, Sendable {
  public let kind: OverlayKind
  public let source: OverlaySource
  public let generation: Int
}

public enum OverlayChange: Equatable, Sendable {
  case show(OverlayPresentation)
  case hide(OverlayKind)
}

public struct OverlayBoard: Sendable {
  public private(set) var visible: [OverlayKind: OverlayPresentation] = [:]
  private var generation = 0

  public init() {}

  public mutating func present(_ kind: OverlayKind, from source: OverlaySource) -> [OverlayChange] {
    guard admits(kind, from: source) else { return [] }
    let displaced = source == .live ? kind.displacedByLive : []
    let hides = OverlayKind.allCases.filter { displaced.contains($0) && visible[$0] != nil }
    hides.forEach { visible[$0] = nil }
    generation += 1
    let presentation = OverlayPresentation(kind: kind, source: source, generation: generation)
    visible[kind] = presentation
    return hides.map(OverlayChange.hide) + [.show(presentation)]
  }

  public mutating func dismiss(_ kind: OverlayKind) -> [OverlayChange] {
    guard visible.removeValue(forKey: kind) != nil else { return [] }
    return [.hide(kind)]
  }

  public mutating func expire(_ presentation: OverlayPresentation) -> [OverlayChange] {
    guard visible[presentation.kind] == presentation else { return [] }
    return dismiss(presentation.kind)
  }

  public mutating func dismissLive() -> [OverlayChange] {
    let live = OverlayKind.allCases.filter { visible[$0]?.source == .live }
    return live.flatMap { dismiss($0) }
  }

  public func isLive(_ kind: OverlayKind) -> Bool {
    visible[kind]?.source == .live
  }

  private func admits(_ kind: OverlayKind, from source: OverlaySource) -> Bool {
    switch source {
    case .live:
      return kind.isBreak || !OverlayKind.allCases.contains { $0.isBreak && isLive($0) }
    case .preview:
      let coveredByLive = OverlayKind.allCases.contains { ($0.coversScreens || $0.isBreak) && isLive($0) }
      return !coveredByLive && !isLive(kind)
    }
  }
}
