import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active

  // Core Timings (Seconds)
  private let workDuration: TimeInterval = 20 * 60
  private let nudgeDuration: TimeInterval = 60
  private let breakDuration: TimeInterval = 20
  private let idleThreshold: TimeInterval = 120  // 2 minutes of no movement = Auto Pause

  @Published var timeRemaining: TimeInterval = 20 * 60

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
    let elapsedSinceLastTick = now.timeIntervalSince(lastTickTimestamp)
    lastTickTimestamp = now

    // 1. Check for Idle (Physical absence)
    let idleSeconds = IdleTracker.getSecondsSinceLastInput()
    if idleSeconds > idleThreshold && status != .paused && status != .idle {
      print("User is idle (\(Int(idleSeconds))s). Auto-pausing.")
      transition(to: .paused)
      return
    }

    // 2. Smart Pause Check (Meetings/Fullscreen)
    let inMeeting = SystemHooks.shared.isMeetingInProgress()
    let isFullscreen = SystemHooks.shared.isFullscreenAppActive()

    if (inMeeting || isFullscreen) && (status == .active || status == .nudge) {
      if status != .paused {
        print("Smart Pause triggered (Meeting: \(inMeeting), Fullscreen: \(isFullscreen))")
        transition(to: .paused)
      }
      return
    } else if status == .paused && !inMeeting && !isFullscreen && idleSeconds < 10 {
      // Auto-resume if the meeting ended AND user just moved the mouse
      transition(to: .active)
    }

    // 3. Precision Countdown Logic
    if status == .paused || status == .idle { return }

    timeRemaining -= elapsedSinceLastTick

    if timeRemaining <= 0 {
      autoTransition()
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

  func transition(to newStatus: AppStatus) {
    self.status = newStatus

    switch newStatus {
    case .active: timeRemaining = workDuration
    case .nudge: timeRemaining = nudgeDuration
    case .onBreak: timeRemaining = breakDuration
    case .paused, .idle: break  // Keep current timeRemaining
    }
    print("Transitioned to: \(newStatus)")
  }

  func togglePause() {
    if status == .paused {
      status = .active
    } else {
      status = .paused
    }
  }
}
