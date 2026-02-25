import Foundation
import Testing

@testable import SuperZen

@MainActor
struct SuperZenTests {

  @Test func testStateTransitions() async throws {
    let stateManager = StateManager()
    stateManager.workDuration = 1200
    stateManager.breakDuration = 60

    // Initial state
    #expect(stateManager.status == .active)

    // Transition to nudge
    stateManager.transition(to: .nudge)
    #expect(stateManager.status == .nudge)
    #expect(abs(stateManager.timeRemaining - 60) < 5.0)

    // Transition to onBreak
    stateManager.transition(to: .onBreak)
    #expect(stateManager.status == .onBreak)
    #expect(abs(stateManager.timeRemaining - stateManager.breakDuration) < 5.0)

    // Transition back to active
    stateManager.transition(to: .active)
    #expect(stateManager.status == .active)
    #expect(abs(stateManager.timeRemaining - stateManager.workDuration) < 5.0)
  }

  @Test func testPauseToggle() async throws {
    let stateManager = StateManager()

    // Initial state
    #expect(stateManager.status == .active)

    // Pause
    stateManager.togglePause()
    #expect(stateManager.status == .paused(reason: .manual))

    // Resume
    stateManager.togglePause()
    #expect(stateManager.status == .active)
  }
}
