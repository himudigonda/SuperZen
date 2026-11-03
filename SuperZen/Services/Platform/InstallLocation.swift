import Foundation

nonisolated enum InstallLocation: Equatable {
  case supported
  case translocated
  case readOnlyVolume

  private static let translocationMarker = "/AppTranslocation/"

  static var current: InstallLocation {
    classify(bundleURL: Bundle.main.bundleURL, isReadOnlyVolume: isOnReadOnlyVolume)
  }

  static func classify(bundleURL: URL, isReadOnlyVolume: (URL) -> Bool) -> InstallLocation {
    if bundleURL.path.contains(translocationMarker) { return .translocated }
    return isReadOnlyVolume(bundleURL) ? .readOnlyVolume : .supported
  }

  var allowsLaunchAtLogin: Bool { self == .supported }

  var launchAtLoginExplanation: String? {
    guard !allowsLaunchAtLogin else { return nil }
    return String(
      localized: "Move SuperZen to the Applications folder and open it from there to start it at login.",
      comment: "Shown when launch at login is unavailable because the app runs from a disk image or a download folder")
  }

  private static func isOnReadOnlyVolume(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
  }
}
