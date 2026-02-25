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

    let winWidth: CGFloat = 210  // Matched to compact NudgeOverlay
    let winHeight: CGFloat = 54

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false
    )

    // Initial position driven by alertPosition setting
    let position = UserDefaults.standard.string(forKey: SettingKey.alertPosition) ?? "center"
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let yPos = screen.visibleFrame.maxY - winHeight - 20
    let xPos: CGFloat
    switch position {
    case "left": xPos = screen.visibleFrame.minX + 20
    case "right": xPos = screen.visibleFrame.maxX - winWidth - 20
    default: xPos = screen.visibleFrame.midX - winWidth / 2
    }
    panel.setFrameOrigin(NSPoint(x: xPos, y: yPos))

    panel.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(stateManager))
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.level = .statusBar  // Float above everything
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    // 2. PERMISSION FIX: Ensure window can see mouse events
    panel.orderFrontRegardless()
    windows.append(panel)

    // 3. ZERO-LATENCY HOOK
    MouseTracker.shared.onMove = { [weak panel] pos in
      DispatchQueue.main.async {
        guard let panel = panel else { return }
        let targetPos = NSPoint(x: pos.x + 25, y: pos.y - 60)
        panel.setFrameOrigin(targetPos)
      }
    }
  }

  @MainActor
  func showWellness(type: AppStatus.WellnessType) {
    closeAll()  // Ensure no overlapping windows

    for screen in NSScreen.screens {
      let window = SuperZenOverlayWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered, defer: false
      )

      window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
      window.backgroundColor = .clear
      window.isOpaque = false
      window.hasShadow = false
      window.ignoresMouseEvents = false
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      let view = WellnessOverlayView(type: type)
        .frame(width: screen.frame.width, height: screen.frame.height)

      window.contentView = NSHostingView(rootView: view)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor func closeAll() {
    MouseTracker.shared.onMove = nil
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
  }
}
