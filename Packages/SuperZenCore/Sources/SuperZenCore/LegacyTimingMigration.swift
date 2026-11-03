import Foundation

public enum LegacyTimingMigration {
  public static let workDuration: Double = 1500
  public static let breakDuration: Double = 300

  public static func updates(
    storedVersion: Int, hasCompletedOnboarding: Bool, stored: (LegacyKey) -> Bool
  ) -> [LegacyKey: Double] {
    guard storedVersion == 0, hasCompletedOnboarding else { return [:] }
    let legacy: [LegacyKey: Double] = [.workDuration: workDuration, .breakDuration: breakDuration, .longBreakEvery: 0]
    return legacy.filter { !stored($0.key) }
  }
}
