import AVFoundation
import AppKit
import Foundation

class SystemHooks {
  static let shared = SystemHooks()

  /// Detects if the Camera or Microphone is being used by another app (e.g., Zoom/Meet)
  func isMediaInUse() -> Bool {
    var inUse = false

    // Use DiscoverySession to check device states without starting a capture session
    let audioDevices = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    ).devices

    let videoDevices = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    ).devices

    for device in (audioDevices + videoDevices) where device.isInUseByAnotherApplication {
      inUse = true
      break
    }
    return inUse
  }

  /// Detects if the current active window is in Fullscreen (Game/Movie/Presentation).
  func isFullscreenAppActive() -> Bool {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return false }

    // Use Accessibility API to check window state
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
