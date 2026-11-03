import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct AutomationIntentTests {
  private let defaults = UserDefaults(suiteName: "automation.\(UUID().uuidString)")!
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))

  private func makeManager(onboarded: Bool = true) -> StateManager {
    defaults.set(onboarded, forKey: SettingKey.hasCompletedOnboarding)
    return StateManager(
      defaults: defaults, clock: clock, activity: ScriptedActivity(), context: nil,
      effects: RecordingEffects(), locker: FakeLocker(), hotkeyRegistrar: FakeHotkeyRegistrar(),
      startsAutomatically: false)
  }

  private func route(_ text: String, on manager: StateManager) -> Bool {
    guard let url = URL(string: text) else { return false }
    return CommandRouter.handle(url, on: manager, defaults: defaults)
  }

  @Test func startBreakEntersABreak() {
    let manager = makeManager()
    #expect(route("superzen://start-break", on: manager))
    #expect(manager.status == .onBreak)
  }

  @Test func skipEndsTheBreak() {
    let manager = makeManager()
    manager.startBreak()
    for _ in 0..<12 {
      clock.advance(by: 1)
      manager.tick()
    }
    #expect(manager.status == .onBreak)
    #expect(route("superzen://skip", on: manager))
    #expect(manager.status == .active)
  }

  @Test func pauseWithMinutesPausesUntilThatDeadline() {
    let manager = makeManager()
    #expect(route("superzen://pause?minutes=15", on: manager))
    guard case .paused(let pause) = manager.session.phase else {
      Issue.record("expected paused")
      return
    }
    #expect(pause.until == clock.now.addingTimeInterval(15 * 60))
  }

  @Test func pauseWithoutMinutesPausesIndefinitely() {
    let manager = makeManager()
    #expect(route("superzen://pause", on: manager))
    guard case .paused(let pause) = manager.session.phase else {
      Issue.record("expected paused")
      return
    }
    #expect(pause.until == nil)
  }

  @Test func resumeEndsAUserPause() {
    let manager = makeManager()
    manager.pause(for: nil)
    #expect(route("superzen://resume", on: manager))
    #expect(manager.status == .active)
  }

  @Test func resumeWhenNotPausedDoesNothing() {
    let manager = makeManager()
    #expect(!route("superzen://resume", on: manager))
    #expect(manager.status == .active)
  }

  @Test func postponeRunsWithoutLeavingFocus() {
    let manager = makeManager()
    #expect(route("superzen://postpone", on: manager))
    #expect(manager.status == .active)
  }

  @Test(arguments: [
    "superzen://", "superzen://unknown", "superzen://pause?minutes=0", "superzen://pause?minutes=999",
    "superzen://pause?minutes=-5", "superzen://pause?minutes=abc", "superzen://skip?x=1",
    "https://example.com/start-break", "superzen:start-break", "SUPERZEN://skip",
    "superzen://start-break/../skip", "superzen://pause?minutes=5&minutes=6",
  ])
  func invalidURLsChangeNothing(text: String) {
    let manager = makeManager()
    let before = manager.session
    #expect(!route(text, on: manager))
    #expect(manager.session == before)
  }

  @Test func everyCommandIsRefusedBeforeOnboarding() {
    let manager = makeManager(onboarded: false)
    let before = manager.session
    for text in [
      "superzen://start-break", "superzen://skip", "superzen://pause", "superzen://pause?minutes=5",
      "superzen://resume", "superzen://postpone",
    ] {
      #expect(!route(text, on: manager))
    }
    #expect(manager.session == before)
    #expect(manager.status == .active)
  }

  @Test func statusDescriptionFollowsTheState() {
    let manager = makeManager()
    #expect(CommandRouter.statusDescription(for: manager) == "Focusing")
    manager.pause(for: nil)
    #expect(CommandRouter.statusDescription(for: manager) == "Paused")
  }
}
