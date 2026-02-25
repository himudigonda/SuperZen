import Foundation

enum BreakDifficulty: String, CaseIterable, Identifiable {
  case casual = "Casual"
  case balanced = "Balanced"
  case hardcore = "Hardcore"
  var id: String { rawValue }
}

enum SettingKey {
  static let workDuration = "workDuration"
  static let breakDuration = "breakDuration"
  static let difficulty = "difficulty"
  static let nudgeLeadTime = "nudgeLeadTime"
  static let dontShowWhileTyping = "dontShowWhileTyping"
  static let launchAtLogin = "launchAtLogin"
  static let menuBarDisplay = "menuBarDisplay"
  static let timerStyle = "timerStyle"
  static let postureEnabled = "postureEnabled"
  static let postureFrequency = "postureFrequency"
  static let blinkEnabled = "blinkEnabled"
  static let blinkFrequency = "blinkFrequency"
  static let waterEnabled = "waterEnabled"
  static let waterFrequency = "waterFrequency"
  static let breakBackground = "breakBackground"  // "Wallpaper" | "Gradient" | "Custom"
  static let blurBackground = "blurBackground"
  static let customImagePath = "customImagePath"
  static let alertPosition = "alertPosition"  // "left" | "center" | "right"

  /// Call once at app launch so UserDefaults always has sane values even before
  /// the user has opened Settings for the first time.
  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      workDuration: 1200.0,
      breakDuration: 60.0,
      nudgeLeadTime: 10.0,
      postureEnabled: true,
      postureFrequency: 600.0,
      blinkEnabled: true,
      blinkFrequency: 300.0,
      waterEnabled: true,
      waterFrequency: 1200.0,
      breakBackground: "Wallpaper",
      blurBackground: true,
      alertPosition: "center",
    ])
  }
}
