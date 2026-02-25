import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  // Master Status
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  // Wellness Accumulators (Unified with clock)
  private var lastPostureTime: Date = Date()
  private var lastBlinkTime: Date = Date()
  private var lastWaterTime: Date = Date()

  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1200 {
    didSet { if status == .active { timeRemaining = workDuration } }
  }
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 60 {
    didSet { if status == .onBreak { timeRemaining = breakDuration } }
  }
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.nudgeLeadTime) var nudgeLeadTime: Double = 10

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  /// Seconds the user must wait before they are allowed to skip (Balanced mode).
  private var skipLockDuration: Double { min(20.0, breakDuration * 0.5) }

  var canSkip: Bool {
    switch difficulty {
    case .casual: return true
    case .balanced: return timeRemaining <= breakDuration - skipLockDuration
    case .hardcore: return false
    }
  }

  var skipSecondsRemaining: Int {
    max(0, Int(ceil(timeRemaining - (breakDuration - skipLockDuration))))
  }

  private var timer: AnyCancellable?
  private var lastUpdate: Date = Date()
  private var savedWorkTimeRemaining: TimeInterval = 0

  init() {
    // Force initial value from storage
    let initialWork = UserDefaults.standard.double(forKey: SettingKey.workDuration)
    self.timeRemaining = initialWork > 0 ? initialWork : 1200
    start()
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
    timer = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.heartbeat() }
  }

  private func heartbeat() {
    if status.isPaused { return }

    let now = Date()
    let delta = now.timeIntervalSince(lastUpdate)
    lastUpdate = now

    // 1. Master Countdown (Active -> Nudge -> Break)
    if status == .active || status == .nudge {
      timeRemaining -= delta

      // Check for Cursor Nudge transition
      if status == .active && timeRemaining <= nudgeLeadTime {
        transition(to: .nudge)
      }

      // Check for Break transition
      if timeRemaining <= 0 {
        transition(to: .onBreak)
      }

      // 2. Wellness Logic (ONLY while focusing)
      checkWellnessReminders(now: now)
    } else if status == .onBreak {
      timeRemaining -= delta
      if timeRemaining <= 0 { transition(to: .active) }
    } else if case .wellness = status {
      timeRemaining -= delta
      if timeRemaining <= 0 { transition(to: .active) }
    }
  }

  private func checkWellnessReminders(now: Date) {
    let defaults = UserDefaults.standard

    // Check Posture
    if defaults.bool(forKey: SettingKey.postureEnabled) {
      let freq = defaults.double(forKey: SettingKey.postureFrequency)
      if now.timeIntervalSince(lastPostureTime) >= (freq > 0 ? freq : 600) {
        lastPostureTime = now
        transition(to: .wellness(type: .posture))
        return
      }
    }

    // Check Blink
    if defaults.bool(forKey: SettingKey.blinkEnabled) {
      let freq = defaults.double(forKey: SettingKey.blinkFrequency)
      if now.timeIntervalSince(lastBlinkTime) >= (freq > 0 ? freq : 300) {
        lastBlinkTime = now
        transition(to: .wellness(type: .blink))
        return
      }
    }

    // Check Water
    if defaults.bool(forKey: SettingKey.waterEnabled) {
      let freq = defaults.double(forKey: SettingKey.waterFrequency)
      if now.timeIntervalSince(lastWaterTime) >= (freq > 0 ? freq : 1200) {
        lastWaterTime = now
        transition(to: .wellness(type: .water))
        return
      }
    }
  }

  func transition(to newStatus: AppStatus) {
    if status == newStatus { return }
    let previousStatus = status
    OverlayWindowManager.shared.closeAll()

    status = newStatus

    switch newStatus {
    case .active:
      if case .wellness = previousStatus {
        timeRemaining = savedWorkTimeRemaining
      } else {
        timeRemaining = workDuration
      }
    case .nudge:
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      timeRemaining = breakDuration
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .wellness(let type):
      savedWorkTimeRemaining = timeRemaining
      timeRemaining = 1.5
      OverlayWindowManager.shared.showWellness(type: type)
      SoundManager.shared.play(.nudge)
    default: break
    }
  }

  func togglePause() {
    if status == .paused {
      status = .active
      lastUpdate = Date()
    } else {
      status = .paused
      OverlayWindowManager.shared.closeAll()
    }
  }
}
