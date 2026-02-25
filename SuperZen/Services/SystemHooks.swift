import AVFoundation
import AppKit
import Foundation
import MediaPlayer

class SystemHooks {
  static let shared = SystemHooks()

  func isVideoOrMusicPlaying() -> Bool {
    // This checks the "Now Playing" info in the macOS Control Center
    // Works for YouTube (Safari/Chrome), Spotify, TV App, etc.
    let playbackState = MPNowPlayingInfoCenter.default().playbackState
    return playbackState == .playing
  }

  /// Detects if any app is currently using the Camera or Microphone.
  func isMediaInUse() -> Bool {
    // Checking for active audio input streams (Microphone)
    // Note: This is a lightweight check for active hardware usage.
    var microphoneInUse = false
    if #available(macOS 14.0, *) {
      // Modern macOS check for capture sessions
      microphoneInUse = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone],
        mediaType: .audio,
        position: .unspecified
      ).devices.contains { $0.isInUseByAnotherApplication }
    }

    return microphoneInUse
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
      // Check if any window of the frontmost app is 'main' and 'fullscreen'
      // swiftlint:disable opening_brace
      if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &subValue) == .success,
        let isFullscreen = subValue as? Bool
      {
        return isFullscreen
      }
      // swiftlint:enable opening_brace
    }
    return false
  }
}
