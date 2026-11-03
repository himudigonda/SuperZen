import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct HotkeyAssignmentTests {
  private let suiteName = "com.himudigonda.SuperZenTests.assign.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let registrar = FakeHotkeyRegistrar()

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  private func makeCenter() -> HotkeyCenter {
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    center.reload()
    return center
  }

  @Test func comboHeldByAnotherAppIsRetriedOnReload() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let held = Hotkey(HotkeyAction.startBreak.defaultCombo)!
    registrar.taken = [held]
    let center = makeCenter()
    #expect(center.statuses[.startBreak] == .blocked(.unavailable))
    registrar.taken = []
    center.reload()
    #expect(registrar.active[.startBreak] == held)
    #expect(center.conflicts.isEmpty)
  }

  @Test func validComboSavesAndRegistersImmediately() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = makeCenter()
    #expect(center.assign("⌃⌥⌘K", to: .startBreak) == nil)
    #expect(defaults.string(forKey: SettingKey.shortcutStartBreak) == "⌃⌥⌘K")
    #expect(registrar.active[.startBreak] == Hotkey("⌃⌥⌘K"))
    #expect(center.conflicts.isEmpty)
  }

  @Test func duplicateIsRejectedWithoutSaving() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = makeCenter()
    #expect(center.assign("⌃⌥⌘P", to: .startBreak) == .duplicate(of: .togglePause))
    #expect(center.assign("⌃⌥⌘B", to: .skipBreak) == .duplicate(of: .startBreak))
    let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
    #expect(stored[SettingKey.shortcutStartBreak] == nil)
    #expect(stored[SettingKey.shortcutSkipBreak] == nil)
  }

  @Test func modifierAndSystemChecksRunBeforeSaving() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = makeCenter()
    #expect(center.assign("⇧K", to: .togglePause) == .needsModifier)
    #expect(center.assign("⌘Q", to: .togglePause) == .reservedBySystem)
    #expect(center.combos[.togglePause] == SettingsCatalog.shortcutTogglePauseDefault)
  }

  @Test func comboClaimedByAnotherAppIsRevertedAndReported() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = makeCenter()
    registrar.taken = [Hotkey("⌃⌥⌘J")!]
    #expect(center.assign("⌃⌥⌘J", to: .skipBreak) == .unavailable)
    #expect(center.combos[.skipBreak] == SettingsCatalog.shortcutSkipBreakDefault)
    #expect(registrar.active[.skipBreak] == Hotkey(SettingsCatalog.shortcutSkipBreakDefault))
    #expect(center.conflicts.isEmpty)
  }

  @Test func startupConflictsAreSurfaced() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    registrar.taken = [Hotkey(SettingsCatalog.shortcutTogglePauseDefault)!]
    let center = makeCenter()
    #expect(center.conflicts == [.togglePause: .unavailable])
  }

  @Test func resetRestoresEveryDefault() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = makeCenter()
    center.assign("⌃⌥⌘K", to: .startBreak)
    center.assign("⌃⌥⌘L", to: .skipBreak)
    center.resetToDefaults()
    #expect(center.combos == HotkeyCenter.combos(in: UserDefaults(suiteName: "\(suiteName).empty")!))
    #expect(registrar.active[.startBreak] == Hotkey(SettingsCatalog.shortcutStartBreakDefault))
  }

  @Test func everyIssueHasAMessage() {
    let issues: [HotkeyIssue] = [
      .unrecognized, .needsModifier, .duplicate(of: .startBreak), .reservedBySystem, .unavailable,
    ]
    #expect(issues.allSatisfy { !$0.message.isEmpty })
  }
}
