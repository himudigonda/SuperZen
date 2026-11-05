import AppKit
import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct OverlayCoordinatorTests {
  private let factory = FakeSurfaceFactory()
  private let scheduler = ManualScheduler()
  private let center = NotificationCenter()
  private let announcer = AnnouncementRecorder()
  private let coordinator: OverlayCoordinator

  init() {
    coordinator = OverlayCoordinator(
      factory: factory, notificationCenter: center, schedule: scheduler.schedule,
      announce: announcer.announce)
  }

  @Test func liveOverlaysAreAnnouncedToVoiceOver() {
    let manager = StateManagerStub.make()
    coordinator.present(.nudge(manager), from: .live)
    coordinator.present(.alert(manager, AlertStyle(position: "left", isPreview: false)), from: .live)
    coordinator.present(.breakScreen(manager), from: .live)
    let expected = [OverlayContent.nudge(manager), .breakScreen(manager)].compactMap(\.announcement)
    #expect(expected.count == 2)
    #expect(announcer.spoken == expected)
  }

  @Test func wellnessAnnouncesItsTitleOnlyWhenLive() {
    coordinator.present(.wellness(.water), from: .preview, for: 1.5)
    #expect(announcer.spoken.isEmpty)
    scheduler.runAll()
    coordinator.present(.wellness(.water), from: .live, for: 20)
    #expect(announcer.spoken == [WellnessKind.water.overlayTitle])
  }

  @Test func blockedPresentationStaysSilent() {
    coordinator.present(.breakScreen(StateManagerStub.make()), from: .live)
    coordinator.present(.wellness(.posture), from: .live, for: 20)
    #expect(announcer.spoken.count == 1)
  }

  @Test func wellnessPreviewNeverTouchesALiveBreak() {
    coordinator.present(.breakScreen(StateManagerStub.make()), from: .live)
    let shown = coordinator.present(.wellness(.posture), from: .preview, for: 1.5)
    #expect(shown == false)
    #expect(factory.surfaces(of: .wellness).isEmpty)
    #expect(factory.surfaces(of: .breakScreen).first?.concealed == 0)
    scheduler.runAll()
    #expect(coordinator.isShowing(.breakScreen))
  }

  @Test func previewExpiryLeavesLaterLiveWellnessAlone() {
    coordinator.present(.wellness(.blink), from: .preview, for: 1.5)
    coordinator.present(.wellness(.water), from: .live, for: 20)
    scheduler.runFirst()
    #expect(coordinator.isShowing(.wellness))
    let surfaces = factory.surfaces(of: .wellness)
    #expect(surfaces.count == 2)
    #expect(surfaces[0].concealed == 1)
    #expect(surfaces[1].concealed == 0)
    scheduler.runAll()
    #expect(surfaces[1].concealed == 1)
  }

  @Test func staleTimerDoesNotCloseAReplacement() {
    let manager = StateManagerStub.make()
    let style = AlertStyle(position: "right", isPreview: true)
    coordinator.present(.alert(manager, style), from: .preview, for: 5)
    coordinator.present(.alert(manager, style), from: .preview, for: 5)
    scheduler.runFirst()
    #expect(coordinator.isShowing(.alert))
    scheduler.runAll()
    #expect(coordinator.isShowing(.alert) == false)
  }

  @Test func screenChangesRelayoutOnlyVisibleSurfaces() {
    coordinator.present(.nudge(StateManagerStub.make()), from: .live)
    coordinator.present(.breakScreen(StateManagerStub.make()), from: .live)
    center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    #expect(factory.surfaces(of: .nudge).first?.relayouts == 0)
    #expect(factory.surfaces(of: .breakScreen).first?.relayouts == 1)
  }

  @Test func liveBreakConcealsNudgeAndAlert() {
    let manager = StateManagerStub.make()
    coordinator.present(.nudge(manager), from: .live)
    coordinator.present(.alert(manager, AlertStyle(position: "left", isPreview: false)), from: .live)
    coordinator.present(.breakScreen(manager), from: .live)
    #expect(factory.surfaces(of: .nudge).first?.concealed == 1)
    #expect(factory.surfaces(of: .alert).first?.concealed == 1)
    #expect(coordinator.isShowing(.breakScreen))
  }

  @Test func dismissLiveKeepsAPreviewAlert() {
    let manager = StateManagerStub.make()
    coordinator.present(.nudge(manager), from: .live)
    coordinator.present(.alert(manager, AlertStyle(position: "center", isPreview: true)), from: .preview)
    coordinator.dismissLive()
    #expect(coordinator.isShowing(.nudge) == false)
    #expect(coordinator.isShowing(.alert))
  }
}

@MainActor
@Suite(.serialized)
struct HotkeyCenterTests {
  private let suiteName = "com.himudigonda.SuperZenTests.hotkeys.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let registrar = FakeHotkeyRegistrar()

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  @Test func registersDefaultsWithoutAnyPermissionPrompt() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    center.reload()
    #expect(registrar.active.count == 3)
    #expect(registrar.active[.startBreak] == Hotkey("⌃⌥⌘B"))
    #expect(center.statuses.values.allSatisfy { $0.issue == nil })
  }

  @Test func conflictsAreReportedAndNotRegistered() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("⌃⌥⌘B", forKey: SettingKey.shortcutSkipBreak)
    defaults.set("⌃⌥⌘P", forKey: SettingKey.shortcutTogglePause)
    registrar.taken = [Hotkey("⌃⌥⌘P")!]
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    center.reload()
    #expect(center.statuses[.skipBreak] == .blocked(.duplicate(of: .startBreak)))
    #expect(center.statuses[.togglePause] == .blocked(.unavailable))
    #expect(registrar.active.keys.sorted { $0.rawValue < $1.rawValue } == [.startBreak])
  }

  @Test func reloadOnlyReRegistersWhenCombosChange() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    center.reload()
    center.reload()
    #expect(registrar.registrations == 3)
    defaults.set("⌃⌥⌘K", forKey: SettingKey.shortcutStartBreak)
    center.reload()
    #expect(registrar.registrations == 6)
    #expect(registrar.active[.startBreak] == Hotkey("⌃⌥⌘K"))
  }

  @Test func pressesReachTheAction() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    var received: [HotkeyAction] = []
    center.onAction = { received.append($0) }
    registrar.onPress?(.skipBreak)
    #expect(received == [.skipBreak])
  }

  @Test func previewUsesSystemReservedShortcuts() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    registrar.reserved = [Hotkey("⌃⌥⌘S")!]
    let center = HotkeyCenter(registrar: registrar, defaults: defaults)
    let plan = center.preview(HotkeyCenter.combos(in: defaults))
    #expect(plan[.skipBreak] == .blocked(.reservedBySystem))
  }
}

@MainActor
@Suite struct FocusHandoffTests {
  @Test func breakReturnsFocusToTheAppTheUserWasIn() {
    let activator = FakeActivator(frontmost: 42)
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    #expect(activator.isOwnAppActive)
    handoff.giveBack()
    #expect(activator.activated == [42])
  }

  @Test func repeatedTakeKeepsTheOriginalApp() {
    let activator = FakeActivator(frontmost: 42)
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    handoff.take()
    handoff.giveBack()
    #expect(activator.activated == [42])
  }

  @Test func focusStaysPutWhenSuperZenWasAlreadyFrontmost() {
    let activator = FakeActivator(frontmost: 1)
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    handoff.giveBack()
    #expect(activator.activated.isEmpty)
  }

  @Test func focusIsNotStolenBackWhenTheUserAlreadyLeft() {
    let activator = FakeActivator(frontmost: 42)
    let handoff = FocusHandoff(activator: activator)
    handoff.take()
    activator.isOwnAppActive = false
    handoff.giveBack()
    handoff.giveBack()
    #expect(activator.activated.isEmpty)
  }
}
