import Foundation
import SwiftData

@Model
final class FocusSession {
  var id: UUID = UUID()
  var startTime: Date = Date()
  var endTime: Date?
  var activeSeconds: Double = 0
  var idleSeconds: Double = 0
  var interruptions: Int = 0
  var skips: Int = 0

  init() {}

  /// Backward-compatible aggregate for older dashboard code.
  var duration: TimeInterval { activeSeconds + idleSeconds }
}

@Model
final class BreakEvent {
  var id: UUID
  var timestamp: Date
  var type: String  // "Macro" or "Micro"
  var wasCompleted: Bool
  var durationTaken: TimeInterval

  init(type: String, wasCompleted: Bool, durationTaken: TimeInterval) {
    id = UUID()
    timestamp = Date()
    self.type = type
    self.wasCompleted = wasCompleted
    self.durationTaken = durationTaken
  }
}

@Model
final class WellnessEvent {
  var id: UUID = UUID()
  var timestamp: Date = Date()
  var type: String
  var action: String

  init(type: String, action: String) {
    self.type = type
    self.action = action
  }
}
