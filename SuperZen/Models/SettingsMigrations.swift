import Foundation
import SuperZenCore

enum SettingsMigrations {
  static func run(in defaults: UserDefaults) {
    migrateWellnessCadence(in: defaults)
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
