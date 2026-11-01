import CoreGraphics
import SuperZenCore

@MainActor
final class SystemActivityMonitor: ActivityMonitoring {
  private static let inputEvents: [CGEventType] = [
    .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel, .leftMouseDragged,
  ]

  func sample() -> ActivitySample {
    ActivitySample(
      secondsSinceInput: Self.inputEvents.map(Self.secondsSince).min() ?? 0,
      secondsSinceKeyboard: Self.secondsSince(.keyDown))
  }

  private static func secondsSince(_ type: CGEventType) -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
  }
}
