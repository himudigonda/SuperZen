import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0
  @Published var canSkip: Bool = false
  @Published var skipSecondsRemaining: Int = 0

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

  private var lastUpdate: Date = .init()
  private var timer: AnyCancellable?

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
    let now = Date()
    let delta = now.timeIntervalSince(lastUpdate)
    lastUpdate = now

    // 1. Basic Guard: Don't tick if paused
    if status.isPaused { return }

    // 2. Physical Countdown
    timeRemaining -= delta

    // 3. Status Transitions
    if status == .active && timeRemaining <= nudgeLeadTime {
      status = .nudge
      OverlayWindowManager.shared.showNudge(with: self)
    }

    // 4. Trigger auto-switch at zero
    if timeRemaining <= 0 {
      autoTransition()
    }

    // 5. Update UI state for Skip button
    if status == .onBreak {
      updateSkipLogic()
    }
  }

  func transition(to newStatus: AppStatus) {
    if status == newStatus { return }
    OverlayWindowManager.shared.closeAll()

    status = newStatus
    lastUpdate = Date()

    switch newStatus {
    case .active:
      timeRemaining = workDuration
    case .onBreak:
      timeRemaining = breakDuration
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .nudge:
      // Let the timer continue its descent towards zero
      OverlayWindowManager.shared.showNudge(with: self)
    case .idle, .paused:
      break
    }
  }

  private func autoTransition() {
    if status == .active || status == .nudge {
      // Finished work block -> Start Break
      transition(to: .onBreak)
    } else if status == .onBreak {
      // Finished break -> Back to work
      transition(to: .active)
      SoundManager.shared.play(.breakEnd)
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

  private func updateSkipLogic() {
    let diff = BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
    let elapsed = breakDuration - timeRemaining

    switch diff {
    case .casual:
      canSkip = true
      skipSecondsRemaining = 0
    case .balanced:
      skipSecondsRemaining = Int(max(0, ceil(5.0 - elapsed)))
      canSkip = elapsed >= 5.0
    case .hardcore:
      canSkip = false
      skipSecondsRemaining = 99
    }
  }
}
