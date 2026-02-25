import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 10  // Start with testing default

  // Testing Defaults (10s work, 4s break)
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 10
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 4
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowWhileTyping = true
  @AppStorage(SettingKey.smartPauseMeetings) var pauseMeetings = true
  @AppStorage(SettingKey.smartPauseFullscreen) var pauseFullscreen = true

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  private let idleThreshold: TimeInterval = 120
  private var breakStartTimestamp: Date?

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

  // MARK: - Heartbeat

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

    // Telemetry logging
    handleTelemetry(from: oldStatus, to: newStatus)

    // Overlay window lifecycle
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

    // Timer resets
    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .nudge:
      timeRemaining = 60
    case .onBreak:
      timeRemaining = breakDuration
      breakStartTimestamp = Date()
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

  /// Returns true if the user is allowed to skip a break given the current difficulty.
  var canSkipBreak: Bool {
    difficulty != .hardcore
  }

  // MARK: - Telemetry

  private func handleTelemetry(from oldStatus: AppStatus, to newStatus: AppStatus) {
    // 1. Break completed normally (timer elapsed)
    if oldStatus == .onBreak && newStatus == .active {
      let duration = Date().timeIntervalSince(breakStartTimestamp ?? Date())
      TelemetryService.shared.logBreak(type: "Macro", completed: true, duration: duration)
      return
    }

    // 2. Break was skipped early (manual transition with time still remaining)
    if oldStatus == .onBreak && newStatus != .active && timeRemaining > 0 {
      TelemetryService.shared.logBreak(type: "Macro", completed: false, duration: 0)
    }

    // 3. Nudge was skipped — user manually pushed to active before break
    if oldStatus == .nudge && newStatus == .active {
      TelemetryService.shared.logBreak(type: "Micro", completed: false, duration: 0)
    }
  }
}
