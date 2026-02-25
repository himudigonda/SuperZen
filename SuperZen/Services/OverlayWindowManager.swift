import AppKit
import SwiftUI

// Custom window allows clicks even when borderless
class SuperZenOverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  private var windows: [NSWindow] = []

  // Cache the nudge window so we don't spam create/destroy it
  private var cachedNudgeWindow: NSWindow?

  @MainActor
  func showBreak(with stateManager: StateManager) {
    closeAll()
    for screen in NSScreen.screens {
      let window = SuperZenOverlayWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )

      let rootView = BreakOverlayView()
        .environmentObject(stateManager)
        .frame(width: screen.frame.width, height: screen.frame.height)

      window.contentView = NSHostingView(rootView: rootView)
      window.backgroundColor = .black
      window.isOpaque = true
      window.hasShadow = false
      window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor
  func showNudge(with stateManager: StateManager) {
    // If it already exists, just make sure it's visible.
    if let existing = cachedNudgeWindow {
      existing.orderFrontRegardless()
      return
    }

    // Window size (400x300) is LARGER than the View size (340x220) to prevent shadow clipping.
    let winWidth: CGFloat = 400
    let winHeight: CGFloat = 300

    let window = SuperZenOverlayWindow(
      contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    window.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(stateManager))
    window.backgroundColor = .clear
    window.isOpaque = false
    window.level = .floating

    // CRITICAL: Disable system shadow to prevent the black box outline
    window.hasShadow = false

    if let screen = NSScreen.main {
      window.setFrame(
        NSRect(
          x: screen.visibleFrame.maxX - winWidth - 10,
          y: screen.visibleFrame.maxY - winHeight - 10,
          width: winWidth,
          height: winHeight), display: true)
    }

    window.orderFrontRegardless()
    cachedNudgeWindow = window
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

  @MainActor func closeAll() {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()

    cachedNudgeWindow?.orderOut(nil)
  }
}
