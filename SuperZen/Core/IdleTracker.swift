import CoreGraphics
import Foundation

class IdleTracker {
  /// Returns the number of seconds since the last system-wide user input (mouse/keyboard).
  ///
  /// Checks multiple CGEventTypes and returns the minimum idle time across all of them.
  /// The previous implementation used `.null` which almost never fires, causing idle time
  /// to always appear huge and `recordActiveTime()` to never be called.
  static func getSecondsSinceLastInput() -> Double {
    let eventTypes: [CGEventType] = [
      .mouseMoved,
      .leftMouseDown,
      .rightMouseDown,
      .keyDown,
      .scrollWheel,
      .leftMouseDragged,
    ]
    var minIdle = Double.greatestFiniteMagnitude
    for eventType in eventTypes {
      let idle = CGEventSource.secondsSinceLastEventType(
        .combinedSessionState, eventType: eventType)
      if idle < minIdle {
        minIdle = idle
      }
    }
    return minIdle == Double.greatestFiniteMagnitude ? 0 : minIdle
  }

  /// Returns the number of seconds since the last keyboard key down event.
  static func getSecondsSinceLastKeyboardInput() -> Double {
    return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
  }
}
