import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1200
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 60
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.breakCounter) var breakCounter: Int = 0
  @AppStorage(SettingKey.longBreakEvery) var longBreakEvery: Int = 4
  @AppStorage(SettingKey.longBreakDuration) var longBreakDuration: Double = 300

  private let nudgeThreshold: TimeInterval = 60
  private var lastUpdate: Date = Date()
  private var timer: AnyCancellable?

  init() {
    self.timeRemaining = workDuration
    start()
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
    // Safe, lightweight timer.
    timer = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.tick() }
  }

  private func tick() {
    guard !status.isPaused && status != .idle else {
      lastUpdate = Date()
      return
    }

    let now = Date()
    let delta = now.timeIntervalSince(lastUpdate)
    lastUpdate = now

    timeRemaining -= delta

    // CONTINUOUS NUDGE LOGIC
    // Seamlessly show the nudge window when time gets low, WITHOUT resetting the clock.
    if status == .active {
      let effectiveNudge = min(nudgeThreshold, workDuration * 0.5)
      if timeRemaining <= effectiveNudge && timeRemaining > 0 {
        status = .nudge
        OverlayWindowManager.shared.showNudge(with: self)
      }
    }

    if timeRemaining <= 0 {
      autoTransition()
    }
  }

  func transition(to newStatus: AppStatus, isLong: Bool = false) {
    if self.status == newStatus { return }

    OverlayWindowManager.shared.closeAll()
    self.status = newStatus
    self.lastUpdate = Date()

    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .nudge:
      // Fallback if forced manually
      timeRemaining = nudgeThreshold
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      timeRemaining = isLong ? longBreakDuration : breakDuration
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .paused, .idle:
      TelemetryService.shared.endFocusSession()
    }
  }

  func togglePause() {
    if status.isPaused {
      transition(to: .active)
    } else {
      transition(to: .paused(reason: .manual))
    }
  }

  func snooze() {
    // Hide nudge, add 5 minutes, stay in the current work cycle.
    OverlayWindowManager.shared.closeAll()
    timeRemaining += 300
    status = .active
    lastUpdate = Date()
  }

  private func autoTransition() {
    if status == .active || status == .nudge {
      breakCounter += 1
      let isLong = (longBreakEvery > 0 && breakCounter % longBreakEvery == 0)
      transition(to: .onBreak, isLong: isLong)
    } else if status == .onBreak {
      transition(to: .active)
      SoundManager.shared.play(.breakEnd)
    }
  }

  var difficulty: BreakDifficulty { BreakDifficulty(rawValue: difficultyRaw) ?? .balanced }
}
