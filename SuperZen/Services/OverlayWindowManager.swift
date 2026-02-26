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
  private var nudgeWindow: NSWindow?
  private var fixedAlertWindow: NSWindow?
  private var fullscreenWindows: [NSWindow] = []
  private var fixedAlertToken = UUID()

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
      fullscreenWindows.append(window)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor
  func showNudge(with stateManager: StateManager) {
    closeNudge()
    closeFixedAlert()

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
    nudgeWindow = panel

    if UserDefaults.standard.bool(forKey: SettingKey.reminderEnabled) {
      showFixedAlert(with: stateManager, isPreview: false)
    }

    // 3. ZERO-LATENCY HOOK
    MouseTracker.shared.startTracking()
    MouseTracker.shared.onMove = { [weak panel] pos in
      guard let panel = panel else { return }
      let targetPos = NSPoint(x: pos.x + 22, y: pos.y - 58)
      panel.setFrameOrigin(targetPos)
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
      fullscreenWindows.append(window)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @MainActor
  func previewFixedAlert(with stateManager: StateManager) {
    showFixedAlert(with: stateManager, isPreview: true)
  }

  @MainActor
  func closeFixedAlert() {
    fixedAlertToken = UUID()
    fixedAlertWindow?.orderOut(nil)
    fixedAlertWindow = nil
  }

  @MainActor
  private func closeNudge() {
    MouseTracker.shared.stopTracking()
    nudgeWindow?.orderOut(nil)
    nudgeWindow = nil
  }

  @MainActor
  private func showFixedAlert(with stateManager: StateManager, isPreview: Bool) {
    closeFixedAlert()

    let winWidth: CGFloat = 440
    let winHeight: CGFloat = 220
    let window = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    window.setFrameOrigin(alertOrigin(size: NSSize(width: winWidth, height: winHeight)))
    window.contentView = NSHostingView(
      rootView: FixedBreakAlertView(isPreview: isPreview).environmentObject(stateManager)
    )
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.orderFrontRegardless()
    fixedAlertWindow = window

    let durationKey = UserDefaults.standard.double(forKey: SettingKey.reminderDuration)
    let duration = max(1.0, durationKey > 0 ? durationKey : 10.0)
    let token = UUID()
    fixedAlertToken = token
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      guard let self, self.fixedAlertToken == token else { return }
      self.closeFixedAlert()
    }
  }

  private func alertOrigin(size: NSSize) -> NSPoint {
    let position = UserDefaults.standard.string(forKey: SettingKey.alertPosition) ?? "center"
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let padding: CGFloat = 40
    let y = screen.visibleFrame.maxY - size.height - padding
    let x: CGFloat
    switch position {
    case "left":
      x = screen.visibleFrame.minX + padding
    case "right":
      x = screen.visibleFrame.maxX - size.width - padding
    default:
      x = screen.visibleFrame.midX - (size.width / 2)
    }
    return NSPoint(x: x, y: y)
  }

  @MainActor
  func closeAll() {
    closeNudge()
    closeFixedAlert()
    fullscreenWindows.forEach { $0.orderOut(nil) }
    fullscreenWindows.removeAll()
  }
}
