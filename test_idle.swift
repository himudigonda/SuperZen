import CoreGraphics
import Foundation

let combined = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
let keyboard = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)

print("Combined idle: \(combined)")
print("Keyboard idle: \(keyboard)")
