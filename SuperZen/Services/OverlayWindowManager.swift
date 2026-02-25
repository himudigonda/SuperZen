import AppKit
import SwiftUI

class OverlayWindowManager {
  static let shared = OverlayWindowManager()

  private var nudgeWindow: NSWindow?
  private var breakWindows: [NSWindow] = []

  @MainActor
  func showNudge(with stateManager: StateManager) {
    if nudgeWindow == nil {
      let view = NudgeOverlay().environmentObject(stateManager)
      let controller = NSHostingController(rootView: view)

      let window = NSWindow(
        contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentViewController = controller
      window.backgroundColor = .clear
      window.isOpaque = false
      window.hasShadow = false
      window.level = .screenSaver  // Above everything
      window.setFrameAutosaveName("SuperZenNudge")

      // Position: Top Right (LookAway style)
      if let screen = NSScreen.main {
        let padding: CGFloat = 20
        let originX = screen.visibleFrame.maxX - 340 - padding
        let originY = screen.visibleFrame.maxY - 200 - padding
        window.setFrame(NSRect(x: originX, y: originY, width: 340, height: 250), display: true)
      }

      nudgeWindow = window
    }
    nudgeWindow?.makeKeyAndOrderFront(nil)
  }

  @MainActor
  func hideNudge() {
    nudgeWindow?.orderOut(nil)
    nudgeWindow = nil
  }

  @MainActor
  func showBreaks(with stateManager: StateManager) {
    // Create a window for EVERY connected screen
    for screen in NSScreen.screens {
      let view = BreakOverlay().environmentObject(stateManager)
      let controller = NSHostingController(rootView: view)

      let window = NSWindow(
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentViewController = controller
      window.backgroundColor = .black
      window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      window.makeKeyAndOrderFront(nil)
      breakWindows.append(window)
    }
  }

  @MainActor
  func hideBreaks() {
    for window in breakWindows {
      window.orderOut(nil)
    }
    breakWindows.removeAll()
  }
}
