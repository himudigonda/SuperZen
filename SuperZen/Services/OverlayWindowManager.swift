import AppKit
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

    // FIX: Make the window larger (420x300) than the actual view (340x220)
    // This gives the SwiftUI drop shadow room to render without hitting the window borders.
    let winWidth: CGFloat = 420
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
    window.hasShadow = false  // Kill the ugly system shadow

    if let screen = NSScreen.main {
      window.setFrame(
        NSRect(
          x: screen.visibleFrame.maxX - winWidth - 10,
          y: screen.visibleFrame.maxY - winHeight - 10,
          width: winWidth,
          height: winHeight
        ), display: true
      )
    }

    window.orderFrontRegardless()
    windows.append(window)
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
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
