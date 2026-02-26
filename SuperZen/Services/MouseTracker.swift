import AppKit
import Combine

class MouseTracker {
  static let shared = MouseTracker()
  private var globalMonitor: Any?
  private var localMonitor: Any?
  private var ticker: AnyCancellable?
  private var targetPosition: CGPoint = NSEvent.mouseLocation
  private var currentPosition: CGPoint = NSEvent.mouseLocation

  /// A direct callback to the window to avoid SwiftUI latency
  var onMove: ((CGPoint) -> Void)?

  init() {
    let events: NSEvent.EventTypeMask = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged,
      .otherMouseDragged,
    ]

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
      self?.targetPosition = NSEvent.mouseLocation
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
      self?.targetPosition = event.locationInWindow
      if let window = event.window {
        self?.targetPosition = window.convertPoint(toScreen: event.locationInWindow)
      } else {
        self?.targetPosition = NSEvent.mouseLocation
      }
      return event
    }

    // Smooth interpolation at high frequency so the nudge follows naturally.
    ticker = Timer.publish(every: 1.0 / 120.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.emitSmoothedPosition()
      }
  }

  private func emitSmoothedPosition() {
    let dx = targetPosition.x - currentPosition.x
    let dy = targetPosition.y - currentPosition.y
    let distance = hypot(dx, dy)

    if distance < 0.5 {
      currentPosition = targetPosition
    } else {
      let alpha: CGFloat = 0.38
      currentPosition.x += dx * alpha
      currentPosition.y += dy * alpha
    }

    onMove?(currentPosition)
  }
}
