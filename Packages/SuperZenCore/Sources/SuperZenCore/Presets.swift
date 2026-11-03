import Foundation

public enum SettingsPreset: String, CaseIterable, Identifiable, Sendable {
  case eyes2020
  case pomodoro
  case deepWork
  case gentle

  public var id: String { rawValue }

  public var workDuration: TimeInterval {
    switch self {
    case .eyes2020: return 1200
    case .pomodoro: return 1500
    case .deepWork: return 3000
    case .gentle: return 2700
    }
  }

  public var shortBreakDuration: TimeInterval {
    switch self {
    case .eyes2020: return 20
    case .pomodoro: return 300
    case .deepWork: return 600
    case .gentle: return 300
    }
  }

  public var longBreakDuration: TimeInterval? {
    switch self {
    case .eyes2020: return 300
    case .pomodoro: return 900
    case .deepWork, .gentle: return nil
    }
  }

  public var longBreakEvery: Int {
    longBreakDuration == nil ? 0 : 4
  }

  public var difficulty: BreakDifficulty {
    switch self {
    case .eyes2020, .pomodoro: return .balanced
    case .deepWork, .gentle: return .casual
    }
  }

  public func apply(to settings: Settings) -> Settings {
    var copy = settings
    copy.timer.workDuration = workDuration
    copy.timer.shortBreakDuration = shortBreakDuration
    copy.timer.longBreakEvery = longBreakEvery
    if let longBreakDuration { copy.timer.longBreakDuration = longBreakDuration }
    copy.skipPolicy.difficulty = difficulty
    return copy
  }

  public func matches(_ settings: Settings) -> Bool {
    let timer = settings.timer
    guard
      timer.workDuration == workDuration,
      timer.shortBreakDuration == shortBreakDuration,
      timer.longBreakEvery == longBreakEvery,
      settings.skipPolicy.difficulty == difficulty
    else { return false }
    guard let longBreakDuration else { return true }
    return timer.longBreakDuration == longBreakDuration
  }

  public static func matching(_ settings: Settings) -> SettingsPreset? {
    allCases.first { $0.matches(settings) }
  }
}
