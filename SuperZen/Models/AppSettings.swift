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
  static let dontShowWhileTyping = "dontShowWhileTyping"

  // Smart Pause Keys
  static let pauseMeetings = "pauseMeetings"
  static let pauseVideo = "pauseVideo"
  static let pauseCalendar = "pauseCalendar"
  static let pauseFocusApps = "pauseFocusApps"
  static let pauseGaming = "pauseGaming"
  static let cooldownMinutes = "cooldownMinutes"
  static let askDidYouTakeBreak = "askDidYouTakeBreak"

  static let launchAtLogin = "launchAtLogin"
  static let menuBarDisplay = "menuBarDisplay"
  static let timerStyle = "timerStyle"

  static let breakCounter = "breakCounter"
  static let longBreakEvery = "longBreakEvery"
  static let longBreakDuration = "longBreakDuration"
}
