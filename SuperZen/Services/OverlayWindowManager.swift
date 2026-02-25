import AppKit
import SwiftUI

class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  private var windows: [NSWindow] = []

  @MainActor
  func showBreak(with stateManager: StateManager) {
    closeAll()

    for screen in NSScreen.screens {
      let window = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )

      let rootView = BreakOverlayView()
        .environmentObject(stateManager)
        .frame(width: screen.frame.width, height: screen.frame.height)

      window.contentViewController = NSHostingController(rootView: rootView)
      window.backgroundColor = .black
      window.isOpaque = true
      window.level = .screenSaver  // High level blocks everything
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor
  func showNudge(with stateManager: StateManager) {
    // Using a temporary view for the nudge instead of a broken file
    let window = NSWindow(
      contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentViewController = NSHostingController(
      rootView:
        Text("Break Starting Soon...")
        .font(.headline)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    )
    window.backgroundColor = .clear
    window.level = .floating
    if let screen = NSScreen.main {
      window.setFrame(
        NSRect(
          x: screen.visibleFrame.maxX - 300, y: screen.visibleFrame.maxY - 100, width: 280,
          height: 80), display: true)
    }
    window.orderFrontRegardless()
    windows.append(window)
  }

  @MainActor func closeAll() {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
