import Foundation
import SwiftData

@Model
final class FocusSession {
  var id: UUID
  var startTime: Date
  var endTime: Date?
  var duration: TimeInterval  // Seconds

  init(startTime: Date = Date()) {
    id = UUID()
    self.startTime = startTime
    duration = 0
  }
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
