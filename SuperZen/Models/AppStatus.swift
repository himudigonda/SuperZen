import Foundation

enum AppStatus: Equatable {
  case idle
  case active
  case nudge  // The cursor-following one
  case onBreak  // The full-screen blocking one
  case wellness(type: WellnessType)  // NEW: Full-screen wellness blocking
  case paused

  enum WellnessType: String {
    case posture, blink, water, affirmation

    /// How long the overlay stays on screen before auto-dismissing.
    var displayDuration: TimeInterval {
      switch self {
      case .posture, .blink, .water: return 1.5
      case .affirmation: return 4.0
      }
    }
  }

  var isPaused: Bool {
    self == .paused || self == .idle
  }

  var description: String {
    switch self {
    case .active: return "Focusing"
    case .onBreak: return "On Break"
    case .wellness(let type):
      return type == .affirmation ? "Affirmation" : "Wellness: \(type.rawValue.capitalized)"
    default: return "Paused"
    }
  }
}
