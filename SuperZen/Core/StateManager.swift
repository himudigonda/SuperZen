import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var workTimeRemaining: TimeInterval = 20 * 60  // 20 mins default
  @Published var nudgeTimeRemaining: TimeInterval = 60  // 1 min nudge
  @Published var breakTimeRemaining: TimeInterval = 20  // 20 sec default

  private var timer: AnyCancellable?

  init() {
    startTimer()
  }

  func startTimer() {
    timer?.cancel()
    // We tick every 1 second.
    // Note: Phase 2 will improve this with absolute timestamp diffs for battery efficiency.
    timer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.tick()
      }
  }

  private func tick() {
    switch status {
    case .active:
      if workTimeRemaining > 0 {
        workTimeRemaining -= 1
      } else {
        transition(to: .nudge)
      }

    case .nudge:
      if nudgeTimeRemaining > 0 {
        nudgeTimeRemaining -= 1
      } else {
        transition(to: .onBreak)
      }

    case .onBreak:
      if breakTimeRemaining > 0 {
        breakTimeRemaining -= 1
      } else {
        transition(to: .active)
      }

    case .paused, .idle:
      break
    }
  }

  func transition(to newStatus: AppStatus) {
    self.status = newStatus
    // Reset timers based on new status
    switch newStatus {
    case .active:
      workTimeRemaining = 20 * 60
    case .nudge:
      nudgeTimeRemaining = 60
    case .onBreak:
      breakTimeRemaining = 20
    default:
      break
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
