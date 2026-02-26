import Foundation

/// Preview-only helper. The real wellness logic lives in StateManager.
@MainActor
class WellnessManager {
  static let shared = WellnessManager()

  func triggerPreview(type: AppStatus.WellnessType) {
    OverlayWindowManager.shared.showWellness(type: type)
    SoundManager.shared.play(.nudge)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      OverlayWindowManager.shared.closeAll()
    }
  }
}
