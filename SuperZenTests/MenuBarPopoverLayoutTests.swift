import AppKit
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct MenuBarPopoverLayoutTests {
  private let suiteName = "com.himudigonda.SuperZenTests.popover.\(UUID().uuidString)"
  private let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  private func makeManager() -> StateManager {
    StateManager(
      defaults: defaults, clock: ManualClock(Date(timeIntervalSince1970: 1_793_620_800)), calendar: .current,
      activity: ScriptedActivity(), effects: RecordingEffects(), locker: FakeLocker(),
      hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
  }

  private func height(of manager: StateManager) -> CGFloat {
    NSHostingView(rootView: MenuBarPopover(stateManager: manager)).fittingSize.height
  }

  @Test(arguments: [false, true])
  func heightStaysPutAcrossEveryState(dayProgressEnabled: Bool) {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(dayProgressEnabled, forKey: SettingKey.dayProgressEnabled)
    let manager = makeManager()
    let focusing = height(of: manager)
    manager.togglePause()
    #expect(manager.menuBar.isPaused)
    #expect(height(of: manager) == focusing)
    manager.togglePause()
    manager.startBreak()
    #expect(manager.menuBar.isOnBreak)
    #expect(height(of: manager) == focusing)
  }
}
