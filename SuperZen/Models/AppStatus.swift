import Foundation

enum AppStatus: Equatable {
  case idle
  case active
  case nudge
  case onBreak
  case paused

  var isPaused: Bool {
    self == .paused
  }

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
