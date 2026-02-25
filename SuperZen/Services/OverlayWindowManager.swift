import AppKit
import Combine
import SwiftUI

/// This allows the borderless window to accept mouse clicks for the Skip button
class SuperZenOverlayWindow: NSWindow {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  private var windows: [NSWindow] = []
  private var mouseCancellable: AnyCancellable?

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
      // CRITICAL: .clear + non-opaque lets the blur see the desktop
      window.backgroundColor = .clear
      window.isOpaque = false
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
    closeAll()

    let winWidth: CGFloat = 220
    let winHeight: CGFloat = 80

    let window = SuperZenOverlayWindow(
      contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    window.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(stateManager))
    window.backgroundColor = .clear
    window.isOpaque = false
    window.level = .statusBar  // Highest level to follow mouse over everything
    window.hasShadow = false
    window.ignoresMouseEvents = true  // Don't block the user's clicks

    window.orderFrontRegardless()
    windows.append(window)

    // HOOK TO MOUSE: Follow cursor position with an offset
    mouseCancellable = MouseTracker.shared.$currentPosition
      .sink { pos in
        // Offset from cursor so it doesn't block the pointer tip
        let offsetPos = NSPoint(x: pos.x + 20, y: pos.y - 70)
        window.setFrameOrigin(offsetPos)
      }
  }

  @MainActor
  func showWellness(type: WellnessManager.NudgeType) {
    for screen in NSScreen.screens {
      let window = NSWindow(
        contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false
      )
      window.level = .screenSaver + 1
      window.backgroundColor = .clear
      window.isOpaque = false

      let view = WellnessOverlayView(type: type)
      window.contentView = NSHostingView(rootView: view)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)

      // Auto-close specific window after 3 seconds
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        window.orderOut(nil)
        self.windows.removeAll(where: { $0 == window })
      }
    }
  }

  @MainActor func closeAll() {
    mouseCancellable?.cancel()
    mouseCancellable = nil
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
