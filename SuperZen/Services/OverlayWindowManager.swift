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

  private static let nudgeOffsetX: CGFloat = 22
  private static let nudgeOffsetY: CGFloat = -58

  // Fixed break-alert geometry. The window is intentionally larger than the visible
  // card so the card's drop shadow has transparent room to fade out instead of being
  // clipped into a hard rectangle by the window edge. These insets MUST match the
  // `.padding` on FixedBreakAlertView's outer frame.
  private static let alertCardSize = NSSize(width: 420, height: 200)
  private static let alertInsetX: CGFloat = 30
  private static let alertInsetY: CGFloat = 40
  private static let alertCardScreenPadding: CGFloat = 40  // visible gap from screen edge to card
  private static var alertWindowSize: NSSize {
    NSSize(
      width: alertCardSize.width + alertInsetX * 2,
      height: alertCardSize.height + alertInsetY * 2)
  }

  @MainActor
  func showBreak(with stateManager: StateManager) {
    closeAll()
    // Fall back to the first screen if NSScreen.main is nil (no focused window) so that
    // exactly one window still becomes key — otherwise the Skip button gets no key events.
    let mainScreen = NSScreen.main ?? NSScreen.screens.first
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

      if screen == mainScreen {
        window.makeKeyAndOrderFront(nil)
      } else {
        window.orderFront(nil)
      }
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

    let nudgeSize = NSSize(width: winWidth, height: winHeight)
    panel.setFrameOrigin(
      Self.clampedNudgeOrigin(forCursor: NSEvent.mouseLocation, size: nudgeSize))
    panel.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(stateManager))
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.level = .statusBar  // Float above everything
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    panel.orderFrontRegardless()
    nudgeWindow = panel

    if UserDefaults.standard.bool(forKey: SettingKey.reminderEnabled) {
      showFixedAlert(with: stateManager, isPreview: false)
    }

    // 3. ZERO-LATENCY HOOK
    MouseTracker.shared.startTracking()
    MouseTracker.shared.onMove = { [weak panel] pos in
      guard let panel = panel else { return }
      panel.setFrameOrigin(Self.clampedNudgeOrigin(forCursor: pos, size: nudgeSize))
    }
  }

  /// Positions the cursor-following nudge pill at `cursor + offset`, but clamps it to the
  /// visible frame of whichever screen the cursor is on so the pill never clips off-screen
  /// (e.g. near the right/bottom edge or across a multi-monitor boundary).
  private static func clampedNudgeOrigin(forCursor cursor: NSPoint, size: NSSize) -> NSPoint {
    let target = NSPoint(x: cursor.x + nudgeOffsetX, y: cursor.y + nudgeOffsetY)
    let screen =
      NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let frame = screen?.visibleFrame else { return target }
    let x = min(max(target.x, frame.minX), max(frame.minX, frame.maxX - size.width))
    let y = min(max(target.y, frame.minY), max(frame.minY, frame.maxY - size.height))
    return NSPoint(x: x, y: y)
  }

  @MainActor
  func showWellness(type: AppStatus.WellnessType) {
    closeAll()  // Ensure no overlapping windows

    let mainScreen = NSScreen.main ?? NSScreen.screens.first
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
      if screen == mainScreen {
        window.makeKeyAndOrderFront(nil)
      } else {
        window.orderFront(nil)
      }
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

    let winSize = Self.alertWindowSize
    let window = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: winSize.width, height: winSize.height),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    window.setFrameOrigin(alertOrigin())
    window.contentView = NSHostingView(
      rootView: FixedBreakAlertView(isPreview: isPreview).environmentObject(stateManager)
    )
    window.backgroundColor = .clear
    window.isOpaque = false
    // The card draws its own SwiftUI drop shadow; a native window shadow would trace the
    // transparent window rectangle and reintroduce the hard-edged border. Keep it off.
    window.hasShadow = false
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

  private func alertOrigin() -> NSPoint {
    let position = UserDefaults.standard.string(forKey: SettingKey.alertPosition) ?? "center"
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .zero }
    let winSize = Self.alertWindowSize
    let cardPad = Self.alertCardScreenPadding
    // The window is larger than the visible card by the transparent shadow inset, so offset
    // by (cardPad - inset) to keep the *card* — not the window — `cardPad` from the screen edge.
    let y = screen.visibleFrame.maxY - winSize.height - (cardPad - Self.alertInsetY)
    let x: CGFloat
    switch position {
    case "left":
      x = screen.visibleFrame.minX + (cardPad - Self.alertInsetX)
    case "right":
      x = screen.visibleFrame.maxX - winSize.width - (cardPad - Self.alertInsetX)
    default:
      x = screen.visibleFrame.midX - (winSize.width / 2)
    }
    return NSPoint(x: x, y: y)
  }

  @MainActor
  func closeWellness() {
    for window in fullscreenWindows {
      window.orderOut(nil)
    }
    fullscreenWindows.removeAll()
  }

  @MainActor
  func closeAll() {
    closeNudge()
    closeFixedAlert()
    closeWellness()
  }
}
