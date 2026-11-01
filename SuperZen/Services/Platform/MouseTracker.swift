import AppKit
import Combine
import SuperZenCore

class MouseTracker {
  static let shared = MouseTracker()
  private var globalMonitor: Any?
  private var localMonitor: Any?
  private var ticker: AnyCancellable?
  private var targetPosition: CGPoint = NSEvent.mouseLocation
  private var follower = CursorFollower(position: NSEvent.mouseLocation, reduceMotion: false)
  private var isTracking = false

  var onMove: ((CGPoint) -> Void)?

  private init() {}

  func startTracking() {
    guard !isTracking else { return }
    isTracking = true

    let events: NSEvent.EventTypeMask = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged,
      .otherMouseDragged,
    ]

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
      self?.targetPosition = NSEvent.mouseLocation
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
      if let window = event.window {
        self?.targetPosition = window.convertPoint(toScreen: event.locationInWindow)
      } else {
        self?.targetPosition = NSEvent.mouseLocation
      }
      return event
    }

    targetPosition = NSEvent.mouseLocation
    follower.jump(to: targetPosition)

    ticker = Timer.publish(every: 1.0 / 120.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.emitSmoothedPosition()
      }
  }

  func stopTracking() {
    guard isTracking else { return }
    isTracking = false

    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
    }
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }
    ticker?.cancel()
    ticker = nil
    onMove = nil
  }

  private func emitSmoothedPosition() {
    follower.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    guard let position = follower.step(toward: targetPosition) else { return }
    onMove?(position)
  }
}
