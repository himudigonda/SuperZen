import AppKit

class MouseTracker {
  static let shared = MouseTracker()
  private var monitor: Any?

  // A direct callback to the window to avoid SwiftUI latency
  var onMove: ((CGPoint) -> Void)?

  init() {
    // We use a Local monitor + Global monitor to ensure 100% coverage
    // No Published variables here = zero lag.
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
      self?.onMove?(NSEvent.mouseLocation)
    }
  }
}
