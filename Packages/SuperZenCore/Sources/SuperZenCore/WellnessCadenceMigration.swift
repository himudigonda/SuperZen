import Foundation

public enum WellnessCadenceMigration {
  public static let currentVersion = 1
  public static let sharedLegacyInterval: TimeInterval = 1200

  public static func updates(storedVersion: Int, posture: Double?, blink: Double?) -> [LegacyKey: Double] {
    guard storedVersion < currentVersion, posture == sharedLegacyInterval, blink == sharedLegacyInterval else {
      return [:]
    }
    let defaults = WellnessSettings()
    return [.postureFrequency: defaults.posture.interval, .blinkFrequency: defaults.blink.interval]
  }
}
