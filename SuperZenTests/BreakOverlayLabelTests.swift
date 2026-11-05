import AppKit
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct BreakOverlayLabelTests {
  private final class TestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
  }

  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let context = FakeContext()
  private let suiteName = "com.himudigonda.SuperZenTests.labels.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let laterX: CGFloat = 656
  private let buttonRowY: CGFloat = 532

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  private func makeManager(difficulty: BreakDifficulty, maxPostpones: Int? = nil) -> StateManager {
    for key in [
      SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled,
    ] {
      defaults.set(false, forKey: key)
    }
    defaults.set(difficulty.rawValue, forKey: SettingKey.difficulty)
    defaults.set(0.1, forKey: SettingKey.balancedSkipLockRatio)
    if let maxPostpones { defaults.set(maxPostpones, forKey: SettingKey.maxPostpones) }
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

  @Test func balancedLaterSlotIsReservedWhileLockedAndWorksOnceUnlocked() {
    let manager = makeManager(difficulty: .balanced)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    #expect(!manager.canSkip)
    #expect(manager.breakOverlayCopy.showsLater)
    #expect(!manager.breakOverlayCopy.canPostpone)
    let window = show(manager)
    defer { window.close() }
    click(window, x: laterX, y: buttonRowY)
    #expect(manager.status == .onBreak)
    #expect(manager.session.postponesUsed == 0)
    clock.advance(by: 3)
    manager.tick()
    settle()
    #expect(manager.canSkip)
    #expect(manager.breakOverlayCopy.canPostpone)
    click(window, x: laterX, y: buttonRowY)
    #expect(manager.status == .active)
    #expect(manager.session.postponesUsed == 1)
  }

  @Test func laterIsDisabledOnceEveryPostponeIsUsed() {
    let manager = makeManager(difficulty: .casual, maxPostpones: 0)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    let copy = manager.breakOverlayCopy
    #expect(copy.showsLater)
    #expect(copy.postponesExhausted)
    #expect(!copy.canPostpone)
    #expect(copy.laterAccessibilityLabel == "No postpones left for this break")
    let window = show(manager)
    defer { window.close() }
    click(window, x: laterX, y: buttonRowY)
    #expect(manager.status == .onBreak)
    #expect(manager.session.postponesUsed == 0)
  }

  @Test func laterNeverAppearsOnHardcoreEvenDuringACall() {
    let manager = makeManager(difficulty: .hardcore)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    #expect(!manager.breakOverlayCopy.showsLater)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos", isMicrophoneInUse: true)
    clock.advance(by: 1)
    manager.tick()
    #expect(manager.canSkip)
    #expect(!manager.breakOverlayCopy.showsLater)
    #expect(!manager.breakOverlayCopy.canPostpone)
  }

  @Test func laterLabelsExplainWhyItIsDisabled() {
    let available = BreakOverlayCopy(
      difficulty: .casual, canSkip: true, skipSecondsRemaining: 0, canPostpone: true)
    let locked = BreakOverlayCopy(difficulty: .balanced, canSkip: false, skipSecondsRemaining: 7)
    let exhausted = BreakOverlayCopy(
      difficulty: .casual, canSkip: true, skipSecondsRemaining: 0, postponesExhausted: true)
    #expect(available.laterAccessibilityLabel == "Postpone break")
    #expect(locked.laterAccessibilityLabel == "Postpone available once skipping unlocks")
    #expect(exhausted.laterAccessibilityLabel == "No postpones left for this break")
  }
}
