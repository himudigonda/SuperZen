import AppKit

class SoundManager {
  static let shared = SoundManager()
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
    case .breakStart: soundName = defaults.string(forKey: SettingKey.soundBreakStart) ?? "Hero"
    case .breakEnd: soundName = defaults.string(forKey: SettingKey.soundBreakEnd) ?? "Glass"
    case .nudge: soundName = defaults.string(forKey: SettingKey.soundNudge) ?? "Pop"
    }
    playName(soundName)
  }

  /// Used by the preview button in Settings — plays a specific sound name directly.
  func preview(_ name: String) {
    playName(name)
  }

  private func playName(_ name: String) {
    if name == "None" { return }
    let volume = Float(UserDefaults.standard.double(forKey: SettingKey.soundVolume))
    let sound = NSSound(named: name)
    sound?.volume = volume > 0 ? volume : 0.8
    sound?.play()
  }
}
