import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  // Skip Logic
  @Published var canSkip: Bool = false
  @Published var skipSecondsRemaining: Int = 5

  // Storage
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 600
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 60
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue

  private var lastUpdate: Date = Date()
  private var timer: AnyCancellable?
  private let skipDelay: Int = 5

  init() {
    self.timeRemaining = workDuration
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

    // 1. Smart Pause Detection (Only transition if the reason is NEW)
    let inMeeting =
      UserDefaults.standard.bool(forKey: SettingKey.pauseMeetings)
      && SystemHooks.shared.isMediaInUse()
    let isGaming =
      UserDefaults.standard.bool(forKey: SettingKey.pauseGaming)
      && SystemHooks.shared.isFullscreenAppActive()

    if inMeeting {
      if status != .paused(reason: .meeting) { transition(to: .paused(reason: .meeting)) }
      return
    }

    if isGaming {
      if status != .paused(reason: .fullscreen) { transition(to: .paused(reason: .fullscreen)) }
      return
    }

    // 2. Auto-Resume from Smart Pause
    if case .paused(let reason) = status, reason != .manual {
      if !inMeeting && !isGaming {
        transition(to: .active)
      }
      return
    }

    // 3. Normal Countdown
    if status.isPaused || status == .idle { return }

    timeRemaining -= delta

    // 4. Handle Skip Countdown (Only during breaks)
    if status == .onBreak && !canSkip {
      // Internal sub-second tracking for skip
      if timeRemaining < (breakDuration - Double(skipDelay)) {
        canSkip = true
      }
      // Simple integer countdown for UI
      let elapsed = Int(breakDuration - timeRemaining)
      skipSecondsRemaining = max(0, skipDelay - elapsed)
    }

    if timeRemaining <= 0 {
      autoTransition()
    }
  }

  func transition(to newStatus: AppStatus, isLong: Bool = false) {
    // IMPORTANT: If we are already in this state, DO NOT reset everything
    if self.status == newStatus { return }

    OverlayWindowManager.shared.closeAll()
    self.status = newStatus
    self.lastUpdate = Date()

    // Reset Skip Logic
    self.canSkip = (difficultyRaw == BreakDifficulty.casual.rawValue)
    self.skipSecondsRemaining = skipDelay

    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .nudge:
      timeRemaining = 10
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      timeRemaining = isLong ? 300 : breakDuration
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
    if status == .active {
      transition(to: .nudge)
    } else if status == .nudge {
      transition(to: .onBreak)
    } else if status == .onBreak {
      transition(to: .active)
    }
  }
}
