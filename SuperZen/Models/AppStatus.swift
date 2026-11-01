import Foundation
import SuperZenCore

enum AppStatus: Equatable {
  case active
  case nudge  // The cursor-following one
  case onBreak  // The full-screen blocking one
  case wellness(type: WellnessType)
  case paused

  typealias WellnessType = WellnessKind

  init(phase: Phase) {
    switch phase {
    case .focus, .naturalBreak: self = .active
    case .nudge: self = .nudge
    case .onBreak: self = .onBreak
    case .wellness(let pulse): self = .wellness(type: pulse.kind)
    case .paused: self = .paused
    }
  }

  var isPaused: Bool {
    self == .paused
  }

  var description: String {
    switch self {
    case .active: return "Focusing"
    case .nudge: return "Break soon"
    case .onBreak: return "On Break"
    case .wellness(let type):
      return type == .affirmation ? "Affirmation" : "Wellness: \(type.rawValue.capitalized)"
    case .paused: return "Paused"
    }
  }
}

extension WellnessKind {
  nonisolated var localizedName: String {
    switch self {
    case .posture: return String(localized: "Posture", comment: "Wellness reminder type name")
    case .blink: return String(localized: "Blink", comment: "Wellness reminder type name")
    case .water: return String(localized: "Water", comment: "Wellness reminder type name")
    case .affirmation:
      return String(localized: "Affirmation", comment: "Wellness reminder type name")
    }
  }
}
