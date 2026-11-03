import AppKit
import SwiftUI

enum MainWindow {
  nonisolated static let id = "main"
  nonisolated static let title = "SuperZen"
  nonisolated static let frameAutosaveName = "SuperZenMainWindow"

  static func opensAtLaunch(hasCompletedOnboarding: Bool, isHostingUnitTests: Bool) -> Bool {
    !hasCompletedOnboarding && !isHostingUnitTests
  }

  static func find() -> NSWindow? {
    find(in: NSApp.windows)
  }

  static func find(in windows: [NSWindow]) -> NSWindow? {
    windows.first {
      $0.frameAutosaveName == frameAutosaveName || $0.identifier?.rawValue.hasPrefix(id) == true
        || $0.title == title
    }
  }

  @discardableResult
  static func persistFrame(of window: NSWindow, named name: String = frameAutosaveName) -> Bool {
    guard window.frameAutosaveName != name else { return false }
    let restored = window.setFrameUsingName(name)
    window.setFrameAutosaveName(name)
    return restored
  }

  static func open(_ openWindow: OpenWindowAction) {
    openWindow(id: id)
    NSApp.activate()
    find()?.makeKeyAndOrderFront(nil)
  }
}

struct WindowFrameAutosave: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { WindowAttachmentView() }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowAttachmentView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else { return }
    MainWindow.persistFrame(of: window)
  }
}
