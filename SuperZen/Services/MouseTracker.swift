import AppKit
import Combine

class MouseTracker: ObservableObject {
  static let shared = MouseTracker()
  @Published var currentPosition: CGPoint = .zero
  private var monitor: Any?

  init() {
    // Track mouse movements globally (even when app is in background)
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
      DispatchQueue.main.async {
        // Use NSEvent.mouseLocation for screen-space coords (not event.locationInWindow)
        _ = event
        self?.currentPosition = NSEvent.mouseLocation
      }
    }
  }

  deinit {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
