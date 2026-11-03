import AppKit
import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite struct AppLifecycleTests {
  private func makeDefaults() -> (UserDefaults, String) {
    let name = "lifecycle.\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
  }

  private func makeManager(defaults: UserDefaults, registrar: FakeHotkeyRegistrar = FakeHotkeyRegistrar())
    -> StateManager
  {
    StateManager(
      defaults: defaults, activity: ScriptedActivity(), effects: RecordingEffects(), locker: FakeLocker(),
      hotkeyRegistrar: registrar, startsAutomatically: false)
  }

  private func migrate(_ defaults: UserDefaults, domain: String) {
    SettingsMigrations.run(in: defaults) { defaults.persistentDomain(forName: domain)?[$0] != nil }
  }

  @Test func breakFromThePopoverReturnsToTheAppUsedBeforeIt() {
    let activator = FakeActivator(frontmost: 1)
    activator.lastExternalProcessID = 42
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    handoff.giveBack()
    #expect(activator.activated == [42])
  }

  @Test func breakFromTheMainWindowStaysInSuperZen() {
    let activator = FakeActivator(frontmost: 1)
    activator.lastExternalProcessID = 42
    activator.isOwnWindowVisible = true
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    handoff.giveBack()
    #expect(activator.activated.isEmpty)
  }

  @Test func reopeningTheRunningAppAsksForTheMainWindow() {
    nonisolated(unsafe) var requests = 0
    let observer = NotificationCenter.default.addObserver(
      forName: MainWindow.reopenRequested, object: nil, queue: nil
    ) { _ in requests += 1 }
    defer { NotificationCenter.default.removeObserver(observer) }
    #expect(AppDelegate().applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
    #expect(requests == 1)
  }

  @Test func onlyTheNewerInstanceYields() {
    #expect(SingleInstance.olderInstances(ownProcessID: 200, runningProcessIDs: [100, 200]) == [100])
    #expect(SingleInstance.olderInstances(ownProcessID: 100, runningProcessIDs: [100, 200]).isEmpty)
    #expect(SingleInstance.olderInstances(ownProcessID: 100, runningProcessIDs: [100]).isEmpty)
  }

  @Test func aQuittingInstanceIsNotTreatedAsAlive() throws {
    #expect(SingleInstance.isAlive(ProcessInfo.processInfo.processIdentifier))
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try process.run()
    process.waitUntilExit()
    #expect(!SingleInstance.isAlive(process.processIdentifier))
  }

  @Test func nudgeNeverTakesClicksFromTheAppBeneathIt() {
    #expect(AppKitOverlaySurfaces.nudgePanel().ignoresMouseEvents)
  }

  @Test func unchangedScreensKeepTheBreakWindowsAndTheirState() {
    var made = 0
    let surface = ScreenSpanningSurface(takesFocus: false) { screen in
      made += 1
      let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      window.alphaValue = 0
      return window
    }
    let screens = NSScreen.screens.count
    surface.reveal()
    #expect(made == screens)
    surface.relayout()
    #expect(made == screens)
    NSApp.windows.filter { $0.alphaValue == 0 }.forEach { $0.orderOut(nil) }
    surface.relayout()
    #expect(made == screens * 2)
    surface.conceal()
    surface.reveal()
    #expect(made == screens * 3)
    surface.conceal()
  }

  @Test func blockedShortcutRecoversWithoutASettingsEdit() throws {
    let (defaults, name) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let registrar = FakeHotkeyRegistrar()
    let hotkey = try #require(Hotkey(SettingsCatalog.shortcutStartBreakDefault))
    registrar.taken = [hotkey]
    let manager = makeManager(defaults: defaults, registrar: registrar)
    manager.hotkeys.reload()
    #expect(manager.hotkeys.statuses[.startBreak] == .blocked(.unavailable))
    registrar.taken = []
    for _ in 0..<29 { manager.tick() }
    #expect(manager.hotkeys.statuses[.startBreak] == .blocked(.unavailable))
    manager.tick()
    #expect(registrar.active[.startBreak] == hotkey)
  }

  @Test func oneXUpgradeKeepsFiveMinuteBreaks() {
    let (defaults, name) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(true, forKey: SettingKey.hasCompletedOnboarding)
    migrate(defaults, domain: name)
    let timer = makeManager(defaults: defaults).session.settings.timer
    #expect(timer.workDuration == 1500)
    #expect(timer.shortBreakDuration == 300)
    #expect(timer.longBreakEvery == 0)
    #expect(SettingsValidation.issues(in: defaults).isEmpty)
  }

  @Test func oneXUpgradeKeepsAnExplicitBreakAndRunsOnce() {
    let (defaults, name) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(true, forKey: SettingKey.hasCompletedOnboarding)
    defaults.set(60.0, forKey: SettingKey.breakDuration)
    migrate(defaults, domain: name)
    let first = makeManager(defaults: defaults).session.settings.timer
    #expect(first.shortBreakDuration == 60)
    #expect(first.workDuration == 1500)
    defaults.removeObject(forKey: SettingKey.workDuration)
    migrate(defaults, domain: name)
    #expect(makeManager(defaults: defaults).session.settings.timer.workDuration == TimerSettings().workDuration)
  }

  @Test func newInstallGetsTheCurrentDefaults() {
    let (defaults, name) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    migrate(defaults, domain: name)
    let timer = makeManager(defaults: defaults).session.settings.timer
    #expect(timer.workDuration == TimerSettings().workDuration)
    #expect(timer.shortBreakDuration == TimerSettings().shortBreakDuration)
  }

  @Test func longBreakChoicesStayLongerThanTheRegularBreak() {
    #expect(SettingsCatalog.longBreakOptions(longerThan: 20).map(\.1) == [120, 300, 600, 900])
    #expect(SettingsCatalog.longBreakOptions(longerThan: 600).map(\.1) == [900])
    #expect(SettingsCatalog.longBreakMinimum(longerThan: 20) == 60)
    #expect(SettingsCatalog.longBreakMinimum(longerThan: 600) == 601)
    #expect(SettingsCatalog.longBreakMinimum(longerThan: .infinity) == 60)
  }

  @Test func durationLabelSurvivesOutOfRangeStoredValues() {
    #expect(DurationFormat.compact(1e20) == "0s")
    #expect(DurationFormat.compact(.nan) == "0s")
    #expect(DurationFormat.compact(90) == "1m 30s")
  }

  @Test func missingCustomImageIsReported() {
    #expect(ZenBackgroundView.isCustomImageMissing(type: "Custom", path: "/nonexistent/image.png"))
    #expect(ZenBackgroundView.isCustomImageMissing(type: "Custom", path: ""))
    #expect(!ZenBackgroundView.isCustomImageMissing(type: "Wallpaper", path: "/nonexistent/image.png"))
  }
}
