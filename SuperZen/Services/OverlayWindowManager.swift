import AppKit
import SwiftUI

class SuperZenOverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  private var nudgeWindow: NSWindow?
  private var breakWindows: [NSWindow] = []

  @MainActor
  func showNudge(with stateManager: StateManager) {
    if nudgeWindow == nil {
      let window = NSWindow(
        contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentViewController = NSHostingController(
        rootView: NudgeOverlay().environmentObject(stateManager))
      window.backgroundColor = .clear
      window.level = .screenSaver
      window.isOpaque = false
      window.hasShadow = true
      window.ignoresMouseEvents = true

      if let screen = NSScreen.main {
        let width: CGFloat = 340
        let height: CGFloat = 220
        window.setFrame(
          NSRect(
            x: screen.visibleFrame.maxX - width - 20, y: screen.visibleFrame.maxY - height - 20,
            width: width, height: height), display: true)
      }
      nudgeWindow = window
    }
    nudgeWindow?.orderFrontRegardless()
  }

  @MainActor
  func showBreaks(with stateManager: StateManager) {
    hideBreaks()
    for screen in NSScreen.screens {
      let window = SuperZenOverlayWindow(
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentViewController = NSHostingController(
        rootView: BreakOverlay().environmentObject(stateManager))
      window.backgroundColor = .black
      window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
      window.makeKeyAndOrderFront(nil)
      breakWindows.append(window)
    }
    // Force the app to become frontmost to block clicks
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor func hideNudge() {
    nudgeWindow?.orderOut(nil)
    nudgeWindow = nil
  }

  @MainActor func hideBreaks() {
    breakWindows.forEach { $0.orderOut(nil) }
    breakWindows.removeAll()
  }
}
