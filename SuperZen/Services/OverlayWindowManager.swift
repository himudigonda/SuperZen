import AppKit
import SwiftUI

class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  private var windows: [NSWindow] = []

  @MainActor
  func showBreak(with stateManager: StateManager) {
    closeAll()
    for screen in NSScreen.screens {
      // EXPLICIT: Create window with screen frame
      let window = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )

      // Force the SwiftUI view to take up every single pixel
      let rootView = BreakOverlayView()
        .environmentObject(stateManager)
        .frame(width: screen.frame.width, height: screen.frame.height)

      window.contentView = NSHostingView(rootView: rootView)
      window.backgroundColor = .black
      window.isOpaque = true
      window.hasShadow = false

      // CRITICAL: Shield level blocks everything including the Dock
      window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
    // Bring app to front to capture input for the Skip button
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor
  func showWellness(type: WellnessManager.NudgeType) {
    closeAll()
    for screen in NSScreen.screens {
      let window = NSWindow(
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.level = .screenSaver + 1
      window.backgroundColor = .clear
      window.isOpaque = false

      let view = WellnessOverlayView(type: type)
      window.contentView = NSHostingView(rootView: view)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }

    // Auto-close wellness nudges after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.closeAll() }
  }

  @MainActor
  func showNudge(with stateManager: StateManager) {
    // Nudge logic matches your high-res screenshots
    let window = NSWindow(
      contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(stateManager))
    window.backgroundColor = .clear
    window.level = .floating
    window.hasShadow = true

    if let screen = NSScreen.main {
      window.setFrame(
        NSRect(
          x: screen.visibleFrame.maxX - 360, y: screen.visibleFrame.maxY - 240, width: 340,
          height: 220), display: true)
    }
    window.orderFrontRegardless()
    windows.append(window)
  }

  @MainActor func closeAll() {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
