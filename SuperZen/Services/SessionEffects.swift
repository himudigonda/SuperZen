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
      record(event)
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

  private func record(_ event: TelemetryEvent) {
    let telemetry = TelemetryService.shared
    switch event {
    case .focusStarted:
      telemetry.startFocusSession()
    case .focusEnded:
      telemetry.endFocusSession()
    case .activeTime(let seconds):
      telemetry.recordActiveTime(seconds: seconds)
    case .idleTime(let seconds):
      telemetry.recordIdleTime(seconds: seconds, isFocusSession: true)
    case .breakEnded(let outcome):
      if !outcome.completed { telemetry.recordSkip() }
      telemetry.endFocusSession()
      telemetry.logBreak(type: outcome.kind.telemetryName, completed: outcome.completed, duration: outcome.rested)
    case .wellnessEnded(let kind, let completed):
      telemetry.logWellness(type: kind, action: completed ? "completed" : "dismissed")
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

extension BreakKind {
  var telemetryName: String {
    switch self {
    case .short: return "Short"
    case .long: return "Long"
    }
  }
}
