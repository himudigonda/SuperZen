import Foundation
import SuperZenCore

@MainActor
protocol SessionEffectPerforming: AnyObject {
  func perform(_ effect: SessionEffect, for manager: StateManager)
}

@MainActor
final class LiveSessionEffects: SessionEffectPerforming {
  private var wellnessToken: UUID?

  func perform(_ effect: SessionEffect, for manager: StateManager) {
    let overlays = OverlayWindowManager.shared
    switch effect {
    case .showNudge:
      wellnessToken = nil
      overlays.showNudge(with: manager)
    case .showBreak:
      wellnessToken = nil
      overlays.showBreak(with: manager)
    case .showWellness(let kind, let duration):
      overlays.showWellness(type: kind)
      scheduleWellnessDismissal(after: duration)
    case .hideOverlays:
      wellnessToken = nil
      overlays.closeAll()
    case .play(let cue):
      SoundManager.shared.play(cue.soundEvent)
    case .telemetry(let event):
      TelemetryService.shared.record(event, at: manager.currentTime)
    }
  }

  private func scheduleWellnessDismissal(after duration: TimeInterval) {
    let token = UUID()
    wellnessToken = token
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      guard let self, self.wellnessToken == token else { return }
      self.wellnessToken = nil
      OverlayWindowManager.shared.closeWellness()
    }
  }
}

extension SoundCue {
  var soundEvent: SoundManager.SoundEvent {
    switch self {
    case .breakStart: return .breakStart
    case .breakEnd: return .breakEnd
    case .nudge: return .nudge
    }
  }
}
