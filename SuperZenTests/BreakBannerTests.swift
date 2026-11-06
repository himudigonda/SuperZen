import AppKit
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct BreakBannerTests {
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let factory = FakeSurfaceFactory()
  private let center = NotificationCenter()
  private let announcer = AnnouncementRecorder()
  private let scheduler = ManualScheduler()
  private let coordinator: OverlayCoordinator
  private let suiteName = "com.himudigonda.SuperZenTests.banner.\(UUID().uuidString)"
  private let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
    coordinator = OverlayCoordinator(
      factory: factory, notificationCenter: center, schedule: scheduler.schedule,
      announce: announcer.announce)
  }

  private func makeManager(
    difficulty: BreakDifficulty, effects: any SessionEffectPerforming = RecordingEffects(),
    locker: FakeLocker = FakeLocker(outcome: false)
  ) -> StateManager {
    for key in [
      SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled,
    ] {
      defaults.set(false, forKey: key)
    }
    defaults.set(difficulty.rawValue, forKey: SettingKey.difficulty)
    defaults.set(0.1, forKey: SettingKey.balancedSkipLockRatio)
    return StateManager(
      defaults: defaults, clock: clock, calendar: .current, activity: ScriptedActivity(), context: FakeContext(),
      effects: effects, locker: locker, hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
  }

  private func settle(_ interval: TimeInterval = 0.4) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
  }

  private func bannerPanel(for manager: StateManager) throws -> NSPanel {
    let surface = AppKitOverlaySurfaces().makeSurface(for: .breakBanner(manager))
    let panelSurface = try #require(surface as? PanelSurface)
    return panelSurface.panel
  }

  private func place(_ panel: NSPanel) {
    panel.setFrameOrigin(CGPoint(x: -6000, y: -6000))
    panel.orderFrontRegardless()
    settle(0.6)
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

  private var skipX: CGFloat {
    OverlayGeometry.bannerWindowSize.width - OverlayGeometry.bannerInset.width - ZenSpacing.lg - 20
  }

  private var centerY: CGFloat { OverlayGeometry.bannerWindowSize.height / 2 }

  @Test func liveBreakBannerConcealsNudgeAndAlert() {
    let manager = StateManagerStub.make()
    coordinator.present(.nudge(manager), from: .live)
    coordinator.present(.alert(manager, AlertStyle(position: "left", isPreview: false)), from: .live)
    coordinator.present(.breakBanner(manager), from: .live)
    #expect(factory.surfaces(of: .nudge).first?.concealed == 1)
    #expect(factory.surfaces(of: .alert).first?.concealed == 1)
    #expect(coordinator.isShowing(.breakBanner))
    #expect(!coordinator.isShowing(.nudge))
    #expect(!coordinator.isShowing(.alert))
  }

  @Test func liveBannerRefusesNudgeAlertAndWellness() {
    let manager = StateManagerStub.make()
    coordinator.present(.breakBanner(manager), from: .live)
    #expect(!coordinator.present(.nudge(manager), from: .live))
    #expect(
      !coordinator.present(.alert(manager, AlertStyle(position: "center", isPreview: false)), from: .live))
    #expect(!coordinator.present(.wellness(.water), from: .live, for: 20))
    #expect(factory.surfaces(of: .nudge).isEmpty)
    #expect(factory.surfaces(of: .alert).isEmpty)
    #expect(factory.surfaces(of: .wellness).isEmpty)
    #expect(coordinator.isShowing(.breakBanner))
  }

  @Test func bannerAnnouncesTheSameAsTheBreakScreen() {
    let manager = StateManagerStub.make()
    coordinator.present(.breakBanner(manager), from: .live)
    #expect(announcer.spoken == [OverlayContent.breakScreen(manager).announcement].compactMap { $0 })
    #expect(announcer.spoken.count == 1)
  }

  @Test func bannerRelayoutsOnScreenChangeAndHidesWithLiveOverlays() {
    coordinator.present(.breakBanner(StateManagerStub.make()), from: .live)
    center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    #expect(factory.surfaces(of: .breakBanner).first?.relayouts == 1)
    coordinator.dismissLive()
    #expect(!coordinator.isShowing(.breakBanner))
    #expect(factory.surfaces(of: .breakBanner).first?.concealed == 1)
  }

  @Test func bannerSkipClick() throws {
    let manager = makeManager(difficulty: .casual)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    let panel = try bannerPanel(for: manager)
    place(panel)
    defer { panel.orderOut(nil) }
    click(panel, x: skipX, y: centerY)
    #expect(manager.status == .active)
  }

  @Test func bannerSkipClickIsDeadWhileTheSkipLockRuns() throws {
    let manager = makeManager(difficulty: .balanced)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    #expect(!manager.canSkip)
    let panel = try bannerPanel(for: manager)
    place(panel)
    defer { panel.orderOut(nil) }
    click(panel, x: skipX, y: centerY)
    #expect(manager.status == .onBreak)
    clock.advance(by: 3)
    manager.tick()
    settle()
    #expect(manager.canSkip)
    click(panel, x: skipX, y: centerY)
    #expect(manager.status == .active)
  }

  @Test func bannerLaterPostponesOnceAllowed() throws {
    let manager = makeManager(difficulty: .casual)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    #expect(manager.menuBar.actions.canPostpone)
    let panel = try bannerPanel(for: manager)
    place(panel)
    defer { panel.orderOut(nil) }
    click(panel, x: skipX - 100, y: centerY)
    #expect(manager.status == .active)
    #expect(manager.session.postponesUsed == 1)
  }

  @Test func bannerPanelIsNonActivatingAndNeverKey() throws {
    let manager = makeManager(difficulty: .casual)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    let panel = try bannerPanel(for: manager)
    #expect(panel.styleMask.contains(.nonactivatingPanel))
    #expect(!panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(!panel.ignoresMouseEvents)
    let frontmostBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let keyBefore = NSApp.keyWindow
    place(panel)
    defer { panel.orderOut(nil) }
    panel.makeKey()
    click(panel, x: skipX - 100, y: centerY)
    #expect(!panel.isKeyWindow)
    #expect(!panel.isMainWindow)
    #expect(NSApp.keyWindow === keyBefore)
    #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmostBefore)
  }

  @Test func bannerPanelDoesNotShieldTheScreen() throws {
    let manager = makeManager(difficulty: .casual)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let panel = try bannerPanel(for: manager)
    #expect(panel.frame.size == OverlayGeometry.bannerWindowSize)
    #expect(panel.level.rawValue < Int(CGShieldingWindowLevel()))
    if let screen = NSScreen.main {
      #expect(panel.frame.width * panel.frame.height < screen.frame.width * screen.frame.height / 10)
    }
    #expect(!OverlayKind.breakBanner.coversScreens)
  }

  @Test func hardcoreRejectsBanner() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(BreakPresentation.banner.rawValue, forKey: SettingKey.breakPresentation)
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    #expect(SettingsValidation.issues(in: defaults).contains(.bannerUnavailableInHardcore))
    #expect(SettingsIssue.bannerUnavailableInHardcore.section == .appearance)
    defaults.set(BreakDifficulty.balanced.rawValue, forKey: SettingKey.difficulty)
    #expect(!SettingsValidation.issues(in: defaults).contains(.bannerUnavailableInHardcore))
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    defaults.set(BreakPresentation.fullScreen.rawValue, forKey: SettingKey.breakPresentation)
    #expect(!SettingsValidation.issues(in: defaults).contains(.bannerUnavailableInHardcore))
  }

  @Test func hardcoreFallsBackToTheFullScreenBreak() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(BreakPresentation.banner.rawValue, forKey: SettingKey.breakPresentation)
    let performer = LiveSessionEffects(overlays: coordinator, defaults: defaults)
    let manager = makeManager(difficulty: .hardcore, effects: performer)
    manager.startBreak()
    #expect(coordinator.isShowing(.breakScreen))
    #expect(!coordinator.isShowing(.breakBanner))
    #expect(factory.surfaces(of: .breakBanner).isEmpty)
  }

  @Test func bannerSettingShowsTheBannerOnOtherDifficulties() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(BreakPresentation.banner.rawValue, forKey: SettingKey.breakPresentation)
    let performer = LiveSessionEffects(overlays: coordinator, defaults: defaults)
    let manager = makeManager(difficulty: .balanced, effects: performer)
    manager.startBreak()
    #expect(coordinator.isShowing(.breakBanner))
    #expect(!coordinator.isShowing(.breakScreen))
  }

  @Test func fullScreenIsTheDefault() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    SettingKey.registerDefaults(in: defaults)
    #expect(defaults.string(forKey: SettingKey.breakPresentation) == "fullScreen")
    let performer = LiveSessionEffects(overlays: coordinator, defaults: defaults)
    let manager = makeManager(difficulty: .casual, effects: performer)
    manager.startBreak()
    #expect(coordinator.isShowing(.breakScreen))
    #expect(!coordinator.isShowing(.breakBanner))
  }

  @Test func lockingTheScreenHidesTheBanner() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(BreakPresentation.banner.rawValue, forKey: SettingKey.breakPresentation)
    let performer = LiveSessionEffects(overlays: coordinator, defaults: defaults)
    let manager = makeManager(difficulty: .casual, effects: performer, locker: FakeLocker(outcome: true))
    manager.startBreak()
    #expect(coordinator.isShowing(.breakBanner))
    manager.lockScreen()
    #expect(!coordinator.isShowing(.breakBanner))
  }

  @Test func presentationSettingResetsWithAppearance() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(BreakPresentation.banner.rawValue, forKey: SettingKey.breakPresentation)
    #expect(defaults.string(forKey: SettingKey.breakPresentation) == "banner")
    SettingsSections.reset(.appearance, in: defaults)
    #expect(defaults.string(forKey: SettingKey.breakPresentation) == SettingsCatalog.breakPresentationDefault)
    #expect(SettingKey.allKeys.contains(SettingKey.breakPresentation))
  }
}
