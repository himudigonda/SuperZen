import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct MenuBarTests {
  private let suiteName = "com.himudigonda.SuperZenTests.menubar.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
    for key in [
      SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled,
    ] {
      defaults.set(false, forKey: key)
    }
  }

  private func makeManager() -> StateManager {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return StateManager(
      defaults: defaults, clock: clock, calendar: calendar, activity: ScriptedActivity(),
      effects: RecordingEffects(), locker: FakeLocker(), hotkeyRegistrar: FakeHotkeyRegistrar(),
      startsAutomatically: false)
  }

  private func advance(_ manager: StateManager, by seconds: Int) {
    for _ in 0..<seconds {
      clock.advance(by: 1)
      manager.tick()
    }
  }

  @Test func managerPublishesTheMenuBarSnapshot() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = makeManager()
    #expect(manager.menuBar.glyph == .focusing)
    #expect(manager.menuBar.nextBreakAt == clock.now.addingTimeInterval(1200))
    advance(manager, by: 1195)
    #expect(manager.menuBar.glyph == .breakSoon)
    #expect(manager.menuBar.actions.canSnooze)
    manager.snoozeNudge()
    #expect(manager.menuBar.glyph == .focusing)
    manager.togglePause()
    #expect(manager.menuBar.isPaused)
    #expect(manager.menuBar.actions.canSkip == false)
  }

  @Test func breakShowsSkipCountdown() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = makeManager()
    manager.startBreak()
    advance(manager, by: 4)
    #expect(manager.menuBar.glyph == .shortBreak)
    #expect(manager.menuBar.actions.skipUnlocksIn == 6)
    #expect(manager.menuBar.nextBreakAt == nil)
  }

  @Test func everyGlyphHasItsOwnSymbol() {
    let symbols = MenuBarGlyph.allCases.map(\.symbolName)
    #expect(Set(symbols).count == symbols.count)
    #expect(MenuBarGlyph.allCases.allSatisfy { !$0.title.isEmpty && !$0.ringCaption.isEmpty })
  }

  @Test func labelHonoursDisplayModeAndTimerStyle() {
    var menu = MenuBarSnapshot.initial
    menu.remaining = 911
    let both = MenuBarLabelContent(menu: menu, display: "Icon and text", timerStyle: .clock)
    #expect(both.showsIcon && both.showsText)
    #expect(both.text == "15:11")
    let iconOnly = MenuBarLabelContent(menu: menu, display: "Icon only", timerStyle: .minutes)
    #expect(iconOnly.showsIcon && !iconOnly.showsText)
    let textOnly = MenuBarLabelContent(menu: menu, display: "Text only", timerStyle: .minutes)
    #expect(!textOnly.showsIcon && textOnly.showsText)
    #expect(textOnly.text == "16m")
  }

  @Test func pausedAndSleepingStatesUseWordsInsteadOfATimer() {
    var menu = MenuBarSnapshot.initial
    menu.remaining = 600
    for glyph in [MenuBarGlyph.paused, .scheduleSleep, .typing] {
      menu.glyph = glyph
      let content = MenuBarLabelContent(menu: menu, display: "Icon and text", timerStyle: .clock)
      #expect(content.text == glyph.compactLabel)
      #expect(content.text != "10:00")
    }
  }

  @Test func spokenSummaryIsNeverEmpty() {
    var menu = MenuBarSnapshot.initial
    for glyph in MenuBarGlyph.allCases {
      menu.glyph = glyph
      #expect(MenuBarLabelContent.spokenSummary(for: menu).hasPrefix("SuperZen"))
    }
  }
}
