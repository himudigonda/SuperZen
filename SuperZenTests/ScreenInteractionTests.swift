import AppKit
import Combine
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

private final class DurationModel: ObservableObject {
  @Published var value: Double = 1200
}

private struct DurationRoot: View {
  @ObservedObject var model: DurationModel
  var minimum = 1

  var body: some View {
    VStack {
      DurationPicker(
        "Length", value: $model.value, options: [("20 minutes", 1200), ("30 minutes", 1800)], minimum: minimum)
      Spacer()
    }
    .padding(.top, 20)
    .frame(width: 700, height: 460)
    .zenOverlayHost()
    .zenThemed()
  }
}

@MainActor
@Suite(.serialized)
struct ScreenInteractionTests {
  private final class TestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
  }

  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let locker = FakeLocker(outcome: false)
  private let defaults = UserDefaults(suiteName: "com.himudigonda.SuperZenTests.screens.\(UUID().uuidString)")!

  private func makeManager(difficulty: BreakDifficulty = .casual) -> StateManager {
    for key in [
      SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled,
    ] {
      defaults.set(false, forKey: key)
    }
    defaults.set(difficulty.rawValue, forKey: SettingKey.difficulty)
    return StateManager(
      defaults: defaults, clock: clock, calendar: .current, activity: ScriptedActivity(),
      effects: RecordingEffects(), locker: locker, hotkeyRegistrar: FakeHotkeyRegistrar(),
      startsAutomatically: false)
  }

  private func settle(_ interval: TimeInterval = 0.4) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
  }

  private func show<V: View>(_ view: V, size: CGSize) -> NSWindow {
    let window = TestWindow(
      contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: view)
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

  private func focusField(_ window: NSWindow, x: CGFloat, y: CGFloat) {
    let location = CGPoint(x: x, y: window.contentView!.bounds.height - y)
    window.makeFirstResponder(window.contentView!.hitTest(location))
    settle()
  }

  private func type(_ window: NSWindow, _ text: String) {
    (window.firstResponder as? NSTextView)?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    settle(0.2)
  }

  @Test func popoverActionsDriveTheSession() {
    let manager = makeManager()
    let height = NSHostingView(rootView: MenuBarPopover(stateManager: manager)).fittingSize.height
    let window = show(MenuBarPopover(stateManager: manager).zenThemed(), size: CGSize(width: 340, height: height))
    defer { window.close() }
    manager.togglePause()
    settle()
    #expect(manager.status == .paused)
    click(window, x: 247, y: 256)
    #expect(manager.status == .active)
    click(window, x: 93, y: 208)
    #expect(manager.status == .onBreak)
    click(window, x: 247, y: 208)
    #expect(manager.status == .active)
  }

  @Test func breakScreenExtendsSkipsAndLocks() {
    let manager = makeManager()
    manager.startBreak()
    let before = manager.timeRemaining
    let window = show(
      BreakOverlayView().environmentObject(manager).zenThemed(), size: CGSize(width: 1100, height: 700))
    defer { window.close() }
    click(window, x: 232, y: 532)
    #expect(manager.timeRemaining == before + 60)
    click(window, x: 868, y: 532)
    #expect(locker.attempts == 1)
    click(window, x: 444, y: 532)
    #expect(manager.status == .active)
  }

  @Test func breakScreenPostponesWithLater() {
    let manager = makeManager()
    manager.startBreak()
    let window = show(
      BreakOverlayView().environmentObject(manager).zenThemed(), size: CGSize(width: 1100, height: 700))
    defer { window.close() }
    click(window, x: 656, y: 532)
    #expect(manager.status == .active)
    #expect(manager.timeRemaining > 60)
  }

  @Test func balancedBreakCannotBeSkippedWhileLocked() {
    let manager = makeManager(difficulty: .balanced)
    manager.startBreak()
    #expect(!manager.canSkip)
    let window = show(
      BreakOverlayView().environmentObject(manager).zenThemed(), size: CGSize(width: 1100, height: 700))
    defer { window.close() }
    click(window, x: 444, y: 532)
    #expect(manager.status == .onBreak)
  }

  @Test func reminderAlertStartsTheBreak() {
    let manager = makeManager()
    for _ in 0..<1190 {
      clock.advance(by: 1)
      manager.tick()
    }
    #expect(manager.status == .nudge)
    let window = show(
      FixedBreakAlertView().environmentObject(manager),
      size: OverlayGeometry.alertWindowSize)
    defer { window.close() }
    click(
      window, x: OverlayGeometry.alertInset.width + 85,
      y: OverlayGeometry.alertInset.height + OverlayGeometry.alertCardSize.height - 36)
    #expect(manager.status == .onBreak)
  }

  @Test func reminderAlertSnoozesTheNudge() {
    let manager = makeManager()
    for _ in 0..<1190 {
      clock.advance(by: 1)
      manager.tick()
    }
    let window = show(
      FixedBreakAlertView().environmentObject(manager),
      size: OverlayGeometry.alertWindowSize)
    defer { window.close() }
    click(
      window, x: OverlayGeometry.alertInset.width + 355,
      y: OverlayGeometry.alertInset.height + OverlayGeometry.alertCardSize.height - 36)
    #expect(manager.status == .active)
    #expect(manager.timeRemaining > 60)
  }

  @Test func reminderAlertSnoozes() {
    let manager = makeManager()
    for _ in 0..<1190 {
      clock.advance(by: 1)
      manager.tick()
    }
    let window = show(
      FixedBreakAlertView().environmentObject(manager),
      size: OverlayGeometry.alertWindowSize)
    defer { window.close() }
    click(
      window, x: OverlayGeometry.alertInset.width + 340,
      y: OverlayGeometry.alertInset.height + OverlayGeometry.alertCardSize.height - 36)
    #expect(manager.status == .active)
    #expect(manager.session.postponesUsed == 1)
  }

  @Test func breakTipsNeverRepeatConsecutively() {
    let suite = UserDefaults(suiteName: "tips-\(UUID().uuidString)")!
    suite.set(true, forKey: SettingKey.breakTipsEnabled)
    var last: String?
    for _ in 0..<40 {
      let tip = BreakTipPicker.pick(for: .short, defaults: suite)
      #expect(tip != nil)
      #expect(tip?.id != last)
      last = tip?.id
    }
    suite.set(false, forKey: SettingKey.breakTipsEnabled)
    #expect(BreakTipPicker.pick(for: .short, defaults: suite) == nil)
  }

  @Test func customDurationAppliesTypedMinutes() {
    let model = DurationModel()
    let window = show(DurationRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, x: 350, y: 36)
    click(window, x: 350, y: 174)
    focusField(window, x: 350, y: 247)
    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: window.firstResponder, from: nil)
    type(window, "25")
    click(window, x: 503, y: 311)
    #expect(model.value == 1500)
  }

  @Test func customDurationRefusesValuesBelowTheFieldMinimum() {
    let model = DurationModel()
    let window = show(DurationRoot(model: model, minimum: 60), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, x: 350, y: 36)
    click(window, x: 350, y: 174)
    focusField(window, x: 350, y: 247)
    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: window.firstResponder, from: nil)
    type(window, "0")
    click(window, x: 503, y: 311)
    #expect(model.value == 1200)
  }
}
