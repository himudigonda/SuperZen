import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 20 * 60

  // Reactive settings — changes automatically cascade into heartbeat
  @AppStorage(SettingKey.workDuration) var workMins = 20
  @AppStorage(SettingKey.breakDuration) var breakSecs = 20
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.smartPauseMeetings) var pauseMeetings = true
  @AppStorage(SettingKey.smartPauseFullscreen) var pauseFullscreen = true

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  private var idleThreshold: TimeInterval = 120

  private var lastTickTimestamp: Date = Date()
  private var timer: AnyCancellable?

  init() {
    startEngine()
  }

  func startEngine() {
    timer?.cancel()
    lastTickTimestamp = Date()
    timer = Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.heartbeat()
      }
  }

  private func heartbeat() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastTickTimestamp)
    lastTickTimestamp = now

    if handleIdle() { return }
    if handleSmartPause() { return }
    if handleAutoResume() { return }

    if status.isPaused { return }
    if status == .idle { return }

    timeRemaining -= elapsed
    if timeRemaining <= 0 { autoTransition() }
  }

  // MARK: - Heartbeat Helpers

  private func handleIdle() -> Bool {
    let idleSeconds = IdleTracker.getSecondsSinceLastInput()
    if idleSeconds > idleThreshold {
      if case .paused(let reason) = status, reason == .idle { return true }
      transition(to: .paused(reason: .idle))
      return true
    }
    return false
  }

  private func handleSmartPause() -> Bool {
    // Respect user preferences
    let inMeeting = pauseMeetings && SystemHooks.shared.isMeetingInProgress()
    let isFullscreen = pauseFullscreen && SystemHooks.shared.isFullscreenAppActive()
    let inCalendar = CalendarService.shared.isUserBusyInCalendar()

    if inMeeting {
      if status != .paused(reason: .meeting) { transition(to: .paused(reason: .meeting)) }
      return true
    } else if isFullscreen {
      if status != .paused(reason: .fullscreen) { transition(to: .paused(reason: .fullscreen)) }
      return true
    } else if inCalendar {
      if status != .paused(reason: .calendar) { transition(to: .paused(reason: .calendar)) }
      return true
    }
    return false
  }

  private func handleAutoResume() -> Bool {
    if case .paused(let reason) = status, reason != .manual {
      let inMeeting = pauseMeetings && SystemHooks.shared.isMeetingInProgress()
      let inCalendar = CalendarService.shared.isUserBusyInCalendar()
      let isFullscreen = pauseFullscreen && SystemHooks.shared.isFullscreenAppActive()
      let idleSeconds = IdleTracker.getSecondsSinceLastInput()

      if !inMeeting && !isFullscreen && !inCalendar && idleSeconds < 5 {
        transition(to: .active)
      }
      return true
    }
    return false
  }

  private func autoTransition() {
    switch status {
    case .active: transition(to: .nudge)
    case .nudge: transition(to: .onBreak)
    case .onBreak: transition(to: .active)
    default: break
    }
  }

  // MARK: - Public Interface

  func transition(to newStatus: AppStatus) {
    let oldStatus = self.status
    self.status = newStatus

    Task { @MainActor in
      if oldStatus == .nudge && newStatus != .nudge {
        OverlayWindowManager.shared.hideNudge()
      }
      if oldStatus == .onBreak && newStatus != .onBreak {
        OverlayWindowManager.shared.hideBreaks()
      }

      switch newStatus {
      case .nudge:
        OverlayWindowManager.shared.showNudge(with: self)
      case .onBreak:
        OverlayWindowManager.shared.showBreaks(with: self)
      default:
        break
      }
    }

    // Load values from settings on transition (reactive to preference changes)
    switch newStatus {
    case .active: timeRemaining = TimeInterval(workMins * 60)
    case .nudge: timeRemaining = 60
    case .onBreak: timeRemaining = TimeInterval(breakSecs)
    default: break
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

  /// Returns true if the user is allowed to skip a break given the current difficulty.
  var canSkipBreak: Bool {
    difficulty != .hardcore
  }
}
