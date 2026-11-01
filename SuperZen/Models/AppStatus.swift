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

  /// Localized display label for menu bar / accessibility surfaces. `description` stays
  /// exactly as-is (asserted verbatim by tests) — this is the display-only counterpart.
  var localizedLabel: String {
    switch self {
    case .active: return String(localized: "Focusing", comment: "Menu bar / accessibility status")
    case .nudge: return String(localized: "Break soon", comment: "Menu bar / accessibility status")
    case .onBreak: return String(localized: "On Break", comment: "Menu bar / accessibility status")
    case .wellness(let type):
      return type == .affirmation
        ? String(localized: "Affirmation", comment: "Menu bar / accessibility status")
        : String(
          localized: "Wellness: \(type.localizedName)",
          comment: "Menu bar / accessibility status: wellness reminder of a specific type")
    case .paused: return String(localized: "Paused", comment: "Menu bar / accessibility status")
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

  nonisolated var overlayTitle: String {
    switch self {
    case .posture:
      return String(
        localized: "Sit Up Straight", comment: "Wellness overlay title: posture reminder")
    case .blink:
      return String(localized: "Blink Your Eyes", comment: "Wellness overlay title: blink reminder")
    case .water:
      return String(localized: "Drink Water", comment: "Wellness overlay title: hydration reminder")
    case .affirmation:
      return String(localized: "Affirmation", comment: "Wellness reminder type name")
    }
  }
}
