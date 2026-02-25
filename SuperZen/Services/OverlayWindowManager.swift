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
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

      // Interaction: This window MUST receive clicks for the skip button to work
      window.isReleasedWhenClosed = false
      window.level = .screenSaver
      window.backgroundColor = .clear
      window.isOpaque = false
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      let rootView = BreakOverlayView()
        .environmentObject(stateManager)
        .frame(width: screen.frame.width, height: screen.frame.height)

      window.contentViewController = NSHostingController(rootView: rootView)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
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
      window.contentViewController = NSHostingController(rootView: view)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }

    // Auto-close wellness nudges after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.closeAll() }
  }

  @MainActor
  func showNudge(with stateManager: StateManager) {
    closeAll()
    for screen in NSScreen.screens {
      let window = NSWindow(
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.level = .screenSaver
      window.backgroundColor = .clear
      window.isOpaque = false

      let view = VStack(spacing: 20) {
        Text("Break Starting Soon...")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text("Get ready to relax")
          .font(.title2)
          .foregroundColor(.white.opacity(0.8))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black.opacity(0.6))

      window.contentViewController = NSHostingController(rootView: view)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
  }

  @MainActor func closeAll() {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
