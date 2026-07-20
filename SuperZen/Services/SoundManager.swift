import AppKit

class SoundManager {
  static let shared = SoundManager()
  // Do not translate: macOS system sound resource identifiers
  static let availableSounds = [
    "None",
    "Basso",
    "Blow",
    "Bottle",
    "Frog",
    "Funk",
    "Glass",
    "Hero",
    "Morse",
    "Ping",
    "Pop",
    "Purr",
    "Sosumi",
    "Submarine",
    "Tink",
  ]

  enum SoundEvent {
    case breakStart, breakEnd, nudge
  }

  func play(_ event: SoundEvent) {
    let defaults = UserDefaults.standard
    let soundName: String
    switch event {
    case .breakStart:
      soundName =
        defaults.string(forKey: SettingKey.soundBreakStart)
        ?? SettingsCatalog
        .soundBreakStartDefault
    case .breakEnd:
      soundName =
        defaults.string(forKey: SettingKey.soundBreakEnd)
        ?? SettingsCatalog
        .soundBreakEndDefault
    case .nudge:
      soundName =
        defaults.string(forKey: SettingKey.soundNudge)
        ?? SettingsCatalog
        .soundNudgeDefault
    }
    playName(soundName)
  }

  /// Used by the preview button in Settings — plays a specific sound name directly.
  /// `volume` overrides the persisted master volume with the live (possibly unsaved) draft
  /// value from the Sound Effects screen, so dragging the slider is audible immediately
  /// instead of only after Save.
  func preview(_ name: String, volume: Float? = nil) {
    playName(name, volumeOverride: volume)
  }

  private func playName(_ name: String, volumeOverride: Float? = nil) {
    if name == "None" { return }
    let volume =
      volumeOverride ?? Float(UserDefaults.standard.double(forKey: SettingKey.soundVolume))
    if volume <= 0 { return }  // Respect mute (volume 0)
    let sound = NSSound(named: name)
    sound?.volume = volume
    sound?.play()
  }
}
