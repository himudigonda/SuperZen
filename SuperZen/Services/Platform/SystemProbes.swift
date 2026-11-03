import AppKit
import CoreAudio

enum MicrophoneActivity {
  static func isAnyInputRunning() -> Bool {
    inputDeviceIDs().contains(where: isRunningSomewhere)
  }

  private static func inputDeviceIDs() -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var byteCount: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &byteCount) == noErr, byteCount > 0 else {
      return []
    }
    var devices = [AudioObjectID](repeating: 0, count: Int(byteCount) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &byteCount, &devices) == noErr else { return [] }
    return devices.filter(hasInputStreams)
  }

  private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioObjectPropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain)
    var byteCount: UInt32 = 0
    return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &byteCount) == noErr && byteCount > 0
  }

  private static func isRunningSomewhere(_ device: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var running: UInt32 = 0
    var byteCount = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(device, &address, 0, nil, &byteCount, &running)
    return status == noErr && running != 0
  }
}

enum FullscreenDetector {
  @MainActor
  static func hasFullscreenWindow(ownedBy pid: pid_t) -> Bool {
    let screenFrames = NSScreen.screens.map(\.frame)
    guard let primaryHeight = screenFrames.first?.height,
      let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]]
    else { return false }
    return windows.contains { window in
      guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
        (window[kCGWindowLayer as String] as? Int) == 0,
        let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
        let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
      else { return false }
      return screenFrames.contains { matches(bounds, screenFrame: $0, primaryHeight: primaryHeight) }
    }
  }

  nonisolated static func matches(_ bounds: CGRect, screenFrame: CGRect, primaryHeight: CGFloat) -> Bool {
    let converted = CGRect(
      x: screenFrame.minX, y: primaryHeight - screenFrame.maxY, width: screenFrame.width, height: screenFrame.height)
    let tolerance: CGFloat = 1
    return abs(bounds.minX - converted.minX) <= tolerance && abs(bounds.minY - converted.minY) <= tolerance
      && abs(bounds.width - converted.width) <= tolerance && abs(bounds.height - converted.height) <= tolerance
  }
}
