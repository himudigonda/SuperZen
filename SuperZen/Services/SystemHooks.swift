import AppKit
import Foundation

class SystemHooks {
  static let shared = SystemHooks()

  // TEMPORARILY DISABLED: Polling this causes main thread freezes.
  // We will re-implement this safely using background event listeners later.
  func isVideoOrMusicPlaying() -> Bool {
    return false
  }

  // TEMPORARILY DISABLED: AVFoundation polling kills the CPU.
  func isMediaInUse() -> Bool {
    return false
  }

  // This one is lightweight and safe to keep.
  func isFullscreenAppActive() -> Bool {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return false }
    let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(appElement, "AXWindows" as CFString, &value)

    guard result == .success, let windows = value as? [AXUIElement] else { return false }

    for window in windows {
      var subValue: AnyObject?
      // swiftlint:disable opening_brace
      if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &subValue) == .success,
        let isFullscreen = subValue as? Bool
      {
        if isFullscreen { return true }
      }
      // swiftlint:enable opening_brace
    }
    return false
  }
}
