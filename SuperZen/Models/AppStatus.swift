import Foundation
import SwiftUI

enum PauseReason: String {
  case manual = "Manual"
  case meeting = "In a Meeting"
  case calendar = "Calendar Event"
  case idle = "User Inactive"
  case fullscreen = "Fullscreen App"
}

enum AppStatus: Equatable {
  case idle
  case active
  case nudge
  case onBreak
  case paused(reason: PauseReason)

  var isPaused: Bool {
    if case .paused = self { return true }
    return false
  }

  var description: String {
    switch self {
    case .idle: return "Idle"
    case .active: return "Focusing"
    case .nudge: return "Break Soon"
    case .onBreak: return "On Break"
    case .paused(let reason): return "Paused: \(reason.rawValue)"
    }
  }
}
