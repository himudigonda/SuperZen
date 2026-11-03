import Foundation
import SuperZenCore

enum SettingsMigrations {
  static func run(in defaults: UserDefaults, isStored: ((String) -> Bool)? = nil) {
    migrateLegacyTiming(in: defaults, isStored: isStored ?? { defaults.object(forKey: $0) != nil })
    migrateWellnessCadence(in: defaults)
  }

  private static func migrateLegacyTiming(in defaults: UserDefaults, isStored: (String) -> Bool) {
    let updates = LegacyTimingMigration.updates(
      storedVersion: defaults.integer(forKey: SettingKey.wellnessCadenceVersion),
      hasCompletedOnboarding: defaults.bool(forKey: SettingKey.hasCompletedOnboarding),
      stored: { isStored($0.rawValue) })
    for (key, value) in updates {
      defaults.set(value, forKey: key.rawValue)
    }
  }

  private static func migrateWellnessCadence(in defaults: UserDefaults) {
    let stored = defaults.integer(forKey: SettingKey.wellnessCadenceVersion)
    guard stored < WellnessCadenceMigration.currentVersion else { return }
    let updates = WellnessCadenceMigration.updates(
      storedVersion: stored,
      posture: defaults.object(forKey: SettingKey.postureFrequency) as? Double,
      blink: defaults.object(forKey: SettingKey.blinkFrequency) as? Double)
    for (key, value) in updates {
      defaults.set(value, forKey: key.rawValue)
    }
    defaults.set(WellnessCadenceMigration.currentVersion, forKey: SettingKey.wellnessCadenceVersion)
  }
}
