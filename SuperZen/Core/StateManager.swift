import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  // Storage (seconds)
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 600  // Default 10m
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 60  // Default 1m
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue

  private var lastUpdate: Date = Date()
  private var timer: AnyCancellable?

  init() {
    // Initialize timer to the saved work duration
    self.timeRemaining = workDuration
    start()
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
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

    if timeRemaining <= 0 {
      autoTransition()
    }
  }

  func transition(to newStatus: AppStatus) {
    // CLOSE EVERYTHING FIRST TO PREVENT CRASHES
    OverlayWindowManager.shared.closeAll()

    self.status = newStatus
    self.lastUpdate = Date()

    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .nudge:
      timeRemaining = 10  // 10 second nudge
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      timeRemaining = breakDuration
      OverlayWindowManager.shared.showBreak(with: self)
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

  private func autoTransition() {
    switch status {
    case .active: transition(to: .nudge)
    case .nudge: transition(to: .onBreak)
    case .onBreak: transition(to: .active)
    default: break
    }
  }

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  var canSkipBreak: Bool {
    difficulty != .hardcore
  }
}
