import Foundation
import Testing

@testable import SuperZen

@MainActor
struct SuperZenTests {

  @Test func testStateTransitions() async throws {
    let stateManager = StateManager()

    // Initial state
    #expect(stateManager.status == .active)

    // Transition to nudge
    stateManager.transition(to: .nudge)
    #expect(stateManager.status == .nudge)
    #expect(stateManager.timeRemaining == 10)

    // Transition to onBreak
    stateManager.transition(to: .onBreak)
    #expect(stateManager.status == .onBreak)
    #expect(stateManager.timeRemaining == stateManager.breakDuration)

    // Transition back to active
    stateManager.transition(to: .active)
    #expect(stateManager.status == .active)
    #expect(stateManager.timeRemaining == stateManager.workDuration)
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
