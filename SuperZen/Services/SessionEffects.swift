import Foundation
import SuperZenCore

@MainActor
protocol SessionEffectPerforming: AnyObject {
  func perform(_ effect: SessionEffect, for manager: StateManager)
}

@MainActor
final class LiveSessionEffects: SessionEffectPerforming {
  private let overlays: OverlayCoordinator
  private let defaults: UserDefaults

  init(overlays: OverlayCoordinator? = nil, defaults: UserDefaults = .standard) {
    self.overlays = overlays ?? .shared
    self.defaults = defaults
  }

  func perform(_ effect: SessionEffect, for manager: StateManager) {
    switch effect {
    case .showNudge:
      overlays.present(.nudge(manager), from: .live)
      presentAlertIfEnabled(for: manager)
    case .showBreak:
      overlays.present(.breakScreen(manager), from: .live)
    case .showWellness(let kind, let duration):
      overlays.present(.wellness(kind), from: .live, for: duration)
    case .hideOverlays:
      overlays.dismissLive()
    case .play(let cue):
      SoundManager.shared.play(cue.soundEvent)
    case .telemetry(let event):
      TelemetryService.shared.record(event, at: manager.currentTime)
    }
  }

  private func presentAlertIfEnabled(for manager: StateManager) {
    guard defaults.bool(forKey: SettingKey.reminderEnabled) else { return }
    let position = defaults.string(forKey: SettingKey.alertPosition) ?? SettingsCatalog.alertPositionDefault
    let duration = defaults.double(forKey: SettingKey.reminderDuration)
    overlays.present(
      .alert(manager, AlertStyle(position: position, isPreview: false)), from: .live,
      for: duration > 0 ? duration : SettingsCatalog.reminderDurationDefault)
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
