import AppKit
import SuperZenCore
import SwiftUI

final class FocusableOverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

@MainActor
struct AppKitOverlaySurfaces: OverlaySurfaceMaking {
  static let breakLevel = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)

  func makeSurface(for content: OverlayContent) -> any OverlaySurface {
    switch content {
    case .breakScreen(let manager):
      return ScreenSpanningSurface(takesFocus: true) { screen in
        let window = FocusableOverlayWindow(
          contentRect: screen.frame, styleMask: [.borderless, .fullSizeContentView],
          backing: .buffered, defer: false)
        Self.style(window, level: Self.breakLevel)
        window.contentView = NSHostingView(
          rootView: BreakOverlayView().environmentObject(manager)
            .frame(width: screen.frame.width, height: screen.frame.height))
        return window
      }
    case .wellness(let kind):
      return ScreenSpanningSurface(takesFocus: false) { screen in
        let panel = Self.passiveScreenPanel(on: screen)
        panel.contentView = NSHostingView(
          rootView: WellnessOverlayView(type: kind)
            .frame(width: screen.frame.width, height: screen.frame.height))
        return panel
      }
    case .nudge(let manager):
      let panel = Self.nudgePanel()
      panel.contentView = NSHostingView(rootView: NudgeOverlay().environmentObject(manager))
      return PanelSurface(panel: panel, followsCursor: true) { cursor in
        OverlayGeometry.nudgeOrigin(cursor: cursor, screens: NSScreen.screens.map(\.area))
      }
    case .alert(let manager, let style):
      let panel = Self.floatingPanel(size: OverlayGeometry.alertWindowSize, level: .floating)
      panel.contentView = NSHostingView(
        rootView: FixedBreakAlertView(isPreview: style.isPreview).environmentObject(manager))
      let placement = AlertPlacement(setting: style.position)
      return PanelSurface(panel: panel, followsCursor: false) { _ in
        let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return OverlayGeometry.alertOrigin(placement: placement, in: frame)
      }
    }
  }

  static func passiveScreenPanel(on screen: NSScreen) -> NSPanel {
    let panel = NSPanel(
      contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    style(panel, level: .screenSaver)
    panel.ignoresMouseEvents = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.hidesOnDeactivate = false
    return panel
  }

  static func nudgePanel() -> NSPanel {
    let panel = floatingPanel(size: OverlayGeometry.nudgeSize, level: .statusBar)
    panel.ignoresMouseEvents = true
    return panel
  }

  static func floatingPanel(size: CGSize, level: NSWindow.Level) -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    style(panel, level: level)
    panel.hidesOnDeactivate = false
    return panel
  }

  private static func style(_ window: NSWindow, level: NSWindow.Level) {
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false
    window.isReleasedWhenClosed = false
    window.level = level
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  }
}

@MainActor
final class ScreenSpanningSurface: OverlaySurface {
  private let takesFocus: Bool
  private let makeWindow: (NSScreen) -> NSWindow
  private let focus = FocusHandoff()
  private var windows: [NSWindow] = []
  private var layout: [CGRect] = []

  init(takesFocus: Bool, makeWindow: @escaping (NSScreen) -> NSWindow) {
    self.takesFocus = takesFocus
    self.makeWindow = makeWindow
  }

  func reveal() {
    relayout()
    if takesFocus { focus.take() }
  }

  func relayout() {
    let frames = NSScreen.screens.map(\.frame)
    guard frames != layout || windows.isEmpty else { return }
    closeWindows()
    layout = frames
    let focusScreen = NSScreen.main ?? NSScreen.screens.first
    windows = NSScreen.screens.map { screen in
      let window = makeWindow(screen)
      window.setFrame(screen.frame, display: false)
      if takesFocus && screen == focusScreen {
        window.makeKeyAndOrderFront(nil)
      } else {
        window.orderFrontRegardless()
      }
      return window
    }
  }

  func conceal() {
    closeWindows()
    if takesFocus { focus.giveBack() }
  }

  private func closeWindows() {
    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()
    layout = []
  }
}

@MainActor
final class PanelSurface: OverlaySurface {
  private let panel: NSPanel
  private let followsCursor: Bool
  private let origin: (CGPoint) -> CGPoint

  init(panel: NSPanel, followsCursor: Bool, origin: @escaping (CGPoint) -> CGPoint) {
    self.panel = panel
    self.followsCursor = followsCursor
    self.origin = origin
  }

  func reveal() {
    relayout()
    panel.orderFrontRegardless()
    guard followsCursor else { return }
    MouseTracker.shared.startTracking()
    MouseTracker.shared.onMove = { [weak self] cursor in
      guard let self else { return }
      self.panel.setFrameOrigin(self.origin(cursor))
    }
  }

  func relayout() {
    panel.setFrameOrigin(origin(NSEvent.mouseLocation))
  }

  func conceal() {
    if followsCursor { MouseTracker.shared.stopTracking() }
    panel.orderOut(nil)
  }
}

extension NSScreen {
  var area: ScreenArea {
    ScreenArea(frame: frame, visibleFrame: visibleFrame)
  }
}
