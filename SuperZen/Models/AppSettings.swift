import Foundation
import SwiftUI

enum BreakDifficulty: String, CaseIterable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"

  var id: String { rawValue }

  var description: String {
    switch self {
    case .casual: return "Skip anytime"
    case .balanced: return "Wait 5s to skip"
    case .hardcore: return "No skips allowed"
    }
  }
}

// Global settings keys
enum SettingKey {
  static let workDuration = "workDuration"
  static let breakDuration = "breakDuration"
  static let difficulty = "difficulty"
  static let launchAtLogin = "launchAtLogin"
  static let menuBarDisplay = "menuBarDisplay"  // "Icon only", "Text only", "Icon and text"
  static let timerStyle = "timerStyle"  // "15:11", "15m", "15"
  static let smartPauseMeetings = "smartPauseMeetings"
  static let smartPauseFullscreen = "smartPauseFullscreen"
}
