import Foundation

/// Preview-only helper. The real wellness logic lives in StateManager.
@MainActor
class WellnessManager {
  static let shared = WellnessManager()

  func triggerPreview(type: AppStatus.WellnessType) {
    OverlayWindowManager.shared.showWellness(type: type)
    SoundManager.shared.play(.nudge)
    // Use closeWellness() (not closeAll()) so a preview triggered from Settings
    // doesn't accidentally kill the nudge or break overlay if one is showing.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      OverlayWindowManager.shared.closeWellness()
    }
  }
}
