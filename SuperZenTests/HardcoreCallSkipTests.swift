import AppKit
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct HardcoreCallSkipTests {
  private final class TestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
  }

  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let context = FakeContext()
  private let suiteName = "com.himudigonda.SuperZenTests.hardcore.\(UUID().uuidString)"
  private let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  private func makeManager() -> StateManager {
    for key in [
      SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled,
    ] {
      defaults.set(false, forKey: key)
    }
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    return StateManager(
      defaults: defaults, clock: clock, calendar: .current, activity: ScriptedActivity(), context: context,
      effects: RecordingEffects(), locker: FakeLocker(outcome: false), hotkeyRegistrar: FakeHotkeyRegistrar(),
      startsAutomatically: false)
  }

  private func settle(_ interval: TimeInterval = 0.4) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
  }

  private func show(_ manager: StateManager) -> NSWindow {
    let size = CGSize(width: 1100, height: 700)
    let window = TestWindow(
      contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: BreakOverlayView().environmentObject(manager).zenThemed())
    window.setContentSize(size)
    window.setFrameOrigin(CGPoint(x: -6000, y: -6000))
    window.orderFront(nil)
    window.makeKey()
    settle(0.6)
    return window
  }

  private func click(_ window: NSWindow, x: CGFloat, y: CGFloat) {
    let location = CGPoint(x: x, y: window.contentView!.bounds.height - y)
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
      window.sendEvent(
        NSEvent.mouseEvent(
          with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
          pressure: type == .leftMouseDown ? 1 : 0)!)
      settle(0.06)
    }
    settle()
  }

  @Test func skipButtonIsDeadUntilACallStartsThenEndsTheBreak() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    let window = show(manager)
    defer { window.close() }
    click(window, x: 550, y: 532)
    #expect(manager.status == .onBreak)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos", isMicrophoneInUse: true)
    clock.advance(by: 1)
    manager.tick()
    settle()
    #expect(manager.canSkip)
    #expect(!manager.menuBar.actions.canPostpone)
    click(window, x: 550, y: 532)
    #expect(manager.status == .active)
    #expect(manager.session.postponesUsed == 0)
  }
}
