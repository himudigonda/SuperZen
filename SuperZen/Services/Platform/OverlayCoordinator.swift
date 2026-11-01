import AppKit
import SuperZenCore

struct AlertStyle: Equatable {
  var position: String
  var isPreview: Bool
}

enum OverlayContent {
  case breakScreen(StateManager)
  case wellness(WellnessKind)
  case nudge(StateManager)
  case alert(StateManager, AlertStyle)

  var kind: OverlayKind {
    switch self {
    case .breakScreen: return .breakScreen
    case .wellness: return .wellness
    case .nudge: return .nudge
    case .alert: return .alert
    }
  }

  var announcement: String? {
    switch self {
    case .breakScreen:
      return String(
        localized: "Break started. Look away from the screen.",
        comment: "VoiceOver announcement when a break screen appears")
    case .nudge:
      return String(
        localized: "Break starting soon.",
        comment: "VoiceOver announcement when the pre-break nudge appears")
    case .wellness(let kind):
      return kind.overlayTitle
    case .alert:
      return nil
    }
  }
}

@MainActor
protocol OverlaySurface: AnyObject {
  func reveal()
  func conceal()
  func relayout()
}

@MainActor
protocol OverlaySurfaceMaking {
  func makeSurface(for content: OverlayContent) -> any OverlaySurface
}

typealias OverlayScheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void
typealias OverlayAnnouncer = @MainActor (String) -> Void

@MainActor
final class OverlayCoordinator {
  static let shared = OverlayCoordinator()

  private(set) var board = OverlayBoard()
  private var surfaces: [OverlayKind: any OverlaySurface] = [:]
  private let factory: any OverlaySurfaceMaking
  private let schedule: OverlayScheduler
  private let announce: OverlayAnnouncer
  private var screenObserver: NSObjectProtocol?

  init(
    factory: (any OverlaySurfaceMaking)? = nil,
    notificationCenter: NotificationCenter = .default,
    schedule: OverlayScheduler? = nil,
    announce: OverlayAnnouncer? = nil
  ) {
    self.factory = factory ?? AppKitOverlaySurfaces()
    self.schedule = schedule ?? Self.afterDelayOnMain
    self.announce = announce ?? Self.postAnnouncement
    screenObserver = notificationCenter.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensDidChange() }
    }
  }

  @discardableResult
  func present(
    _ content: OverlayContent, from source: OverlaySource, for duration: TimeInterval? = nil
  ) -> Bool {
    let changes = board.present(content.kind, from: source)
    apply(changes, content: content)
    guard let presentation = Self.shown(in: changes) else { return false }
    if source == .live, let announcement = content.announcement {
      announce(announcement)
    }
    if let duration {
      schedule(max(0.1, duration)) { [weak self] in self?.expire(presentation) }
    }
    return true
  }

  func dismiss(_ kind: OverlayKind) {
    apply(board.dismiss(kind), content: nil)
  }

  func dismissLive() {
    apply(board.dismissLive(), content: nil)
  }

  func isShowing(_ kind: OverlayKind) -> Bool {
    surfaces[kind] != nil
  }

  func screensDidChange() {
    for kind in OverlayKind.allCases {
      surfaces[kind]?.relayout()
    }
  }

  private func expire(_ presentation: OverlayPresentation) {
    apply(board.expire(presentation), content: nil)
  }

  private func apply(_ changes: [OverlayChange], content: OverlayContent?) {
    for change in changes {
      switch change {
      case .hide(let kind):
        surfaces.removeValue(forKey: kind)?.conceal()
      case .show(let presentation):
        surfaces.removeValue(forKey: presentation.kind)?.conceal()
        guard let content else { continue }
        let surface = factory.makeSurface(for: content)
        surfaces[presentation.kind] = surface
        surface.reveal()
      }
    }
  }

  private static func shown(in changes: [OverlayChange]) -> OverlayPresentation? {
    for change in changes {
      if case .show(let presentation) = change { return presentation }
    }
    return nil
  }

  private static func postAnnouncement(_ text: String) {
    NSAccessibility.post(
      element: NSApp as Any,
      notification: .announcementRequested,
      userInfo: [
        .announcement: text,
        .priority: NSAccessibilityPriorityLevel.high.rawValue,
      ])
  }

  private static func afterDelayOnMain(
    _ delay: TimeInterval, _ work: @escaping @MainActor () -> Void
  ) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      MainActor.assumeIsolated { work() }
    }
  }
}

extension OverlayCoordinator {
  static let wellnessPreviewDuration: TimeInterval = 1.5

  func previewWellness(_ kind: WellnessKind) {
    guard present(.wellness(kind), from: .preview, for: Self.wellnessPreviewDuration) else { return }
    SoundManager.shared.play(.nudge)
  }

  func previewAlert(for manager: StateManager, position: String, duration: TimeInterval) {
    present(
      .alert(manager, AlertStyle(position: position, isPreview: true)), from: .preview,
      for: max(1, duration))
  }
}
