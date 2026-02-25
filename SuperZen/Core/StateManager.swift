import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 10  // Start with test default

  // Core timing settings (storing in seconds)
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 10
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 4
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue

  private var timer: AnyCancellable?
  private var lastUpdate: Date = Date()

  init() {
    start()
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
    timer = Timer.publish(every: 0.1, on: .main, in: .common)  // High frequency for smooth UI
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

  private func autoTransition() {
    switch status {
    case .active:
      transition(to: .nudge)
    case .nudge:
      transition(to: .onBreak)
    case .onBreak:
      transition(to: .active)
    default: break
    }
  }

  func transition(to newStatus: AppStatus) {
    // Window Lifecycle
    if status == .onBreak && newStatus != .onBreak {
      OverlayWindowManager.shared.hideBreaks()
    }
    if status == .nudge && newStatus != .nudge {
      OverlayWindowManager.shared.hideNudge()
    }

    self.status = newStatus
    self.lastUpdate = Date()

    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .nudge:
      timeRemaining = 5  // Test nudge
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      timeRemaining = breakDuration
      OverlayWindowManager.shared.showBreaks(with: self)
    case .paused, .idle:
      TelemetryService.shared.endFocusSession()
    }

    print("Transitioned to: \(newStatus)")
  }

  func togglePause() {
    if case .paused = status {
      transition(to: .active)
    } else {
      transition(to: .paused(reason: .manual))
    }
  }

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  var canSkipBreak: Bool {
    difficulty != .hardcore
  }
}
