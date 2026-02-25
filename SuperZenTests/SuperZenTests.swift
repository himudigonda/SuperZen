import Foundation
import Testing

@testable import SuperZen

@MainActor
struct SuperZenTests {
  @Test func stateTransitions() {
    let stateManager = StateManager()
    stateManager.workDuration = 1200
    stateManager.breakDuration = 60

    // Initial state
    #expect(stateManager.status == .active)

    // Transition to onBreak
    stateManager.transition(to: .onBreak)
    #expect(stateManager.status == .onBreak)
    #expect(abs(stateManager.timeRemaining - stateManager.breakDuration) < 1.0)

    // Transition back to active
    stateManager.transition(to: .active)
    #expect(stateManager.status == .active)
    #expect(abs(stateManager.timeRemaining - stateManager.workDuration) < 1.0)
  }

  @Test func pauseToggle() {
    let stateManager = StateManager()

    // Initial state
    #expect(stateManager.status == .active)

    // Pause
    stateManager.togglePause()
    #expect(stateManager.status == .paused)

    // Resume
    stateManager.togglePause()
    #expect(stateManager.status == .active)
  }
}
