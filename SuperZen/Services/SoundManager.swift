import AppKit
import SwiftUI

class SoundManager {
  static let shared = SoundManager()

  enum SoundEvent {
    case breakStart, breakEnd, posture, blink, nudge
  }

  @AppStorage("masterVolume") var volume: Double = 0.8

  func play(_ event: SoundEvent) {
    let soundName: String
    switch event {
    case .breakStart: soundName = "Hero"
    case .breakEnd: soundName = "Glass"
    case .posture: soundName = "Ping"
    case .blink: soundName = "Purr"
    case .nudge: soundName = "Pop"
    }

    let sound = NSSound(named: soundName)
    sound?.volume = Float(volume)
    sound?.play()
  }
}
