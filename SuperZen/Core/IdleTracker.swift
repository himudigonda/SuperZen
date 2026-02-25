import CoreGraphics
import Foundation

class IdleTracker {
  /// Returns the number of seconds since the last system-wide user input (mouse/keyboard).
  static func getSecondsSinceLastInput() -> Double {
    // This is a low-level CoreGraphics call that doesn't require Accessibility permissions.
    let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
    return idleTime
  }
}
