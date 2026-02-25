import Foundation

enum AppStatus: Equatable {
  case idle  // App is running but timer is stopped
  case active  // User is working, work timer is counting down
  case nudge  // The 60-second warning before a break
  case onBreak  // Full screen overlay is active
  case paused  // Smart Pause active (Meeting, Movie, etc.)

  var description: String {
    switch self {
    case .idle: return "Idle"
    case .active: return "Focusing"
    case .nudge: return "Break Soon"
    case .onBreak: return "On Break"
    case .paused: return "Paused"
    }
  }
}
