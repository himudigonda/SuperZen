import Combine
import Foundation

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 20 * 60

  private let workDuration: TimeInterval = 20 * 60
  private let nudgeDuration: TimeInterval = 60
  private let breakDuration: TimeInterval = 20
  private let idleThreshold: TimeInterval = 120

  private var lastTickTimestamp: Date = Date()
  private var timer: AnyCancellable?

  init() {
    startEngine()
  }

  func startEngine() {
    timer?.cancel()
    lastTickTimestamp = Date()
    timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect().sink { [weak self] _ in
      self?.heartbeat()
    }
  }

  private func heartbeat() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastTickTimestamp)
    lastTickTimestamp = now

    // 1. Idle Check
    if handleIdle() { return }

    // 2. Smart Pause Logic
    if handleSmartPause() { return }

    // 3. Auto-Resume Logic
    if handleAutoResume() { return }

    // 4. Countdown
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
    let inMeeting = SystemHooks.shared.isMeetingInProgress()
    let inCalendar = CalendarService.shared.isUserBusyInCalendar()
    let isFullscreen = SystemHooks.shared.isFullscreenAppActive()

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
      let inMeeting = SystemHooks.shared.isMeetingInProgress()
      let inCalendar = CalendarService.shared.isUserBusyInCalendar()
      let isFullscreen = SystemHooks.shared.isFullscreenAppActive()
      let idleSeconds = IdleTracker.getSecondsSinceLastInput()

      // If the reason for auto-pause is gone, and the user is back, resume
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

    switch newStatus {
    case .active: timeRemaining = workDuration
    case .nudge: timeRemaining = nudgeDuration
    case .onBreak: timeRemaining = breakDuration
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
}
