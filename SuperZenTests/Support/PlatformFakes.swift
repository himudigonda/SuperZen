import AppKit
import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
final class ScriptedActivity: ActivityMonitoring {
  var current: ActivitySample

  init(_ current: ActivitySample = .present) {
    self.current = current
  }

  func sample() -> ActivitySample {
    current
  }
}

@MainActor
final class FakeLocker: ScreenLocking {
  let outcome: Bool
  private(set) var attempts = 0

  init(outcome: Bool = true) {
    self.outcome = outcome
  }

  func lock(then report: @escaping @MainActor (Bool) -> Void) {
    attempts += 1
    report(outcome)
  }
}

@MainActor
final class FakeHotkeyRegistrar: HotkeyRegistering {
  var onPress: ((HotkeyAction) -> Void)?
  var taken: Set<Hotkey> = []
  var reserved: Set<Hotkey> = []
  private(set) var active: [HotkeyAction: Hotkey] = [:]
  private(set) var registrations = 0

  func register(_ hotkey: Hotkey, for action: HotkeyAction) -> Bool {
    registrations += 1
    guard !taken.contains(hotkey) else { return false }
    active[action] = hotkey
    return true
  }

  func unregisterAll() {
    active.removeAll()
  }

  func systemReservedHotkeys() -> Set<Hotkey> {
    reserved
  }
}

@MainActor
final class FakeSurface: OverlaySurface {
  let kind: OverlayKind
  private(set) var revealed = 0
  private(set) var concealed = 0
  private(set) var relayouts = 0

  init(kind: OverlayKind) {
    self.kind = kind
  }

  func reveal() { revealed += 1 }
  func conceal() { concealed += 1 }
  func relayout() { relayouts += 1 }
}

@MainActor
final class FakeSurfaceFactory: OverlaySurfaceMaking {
  private(set) var made: [FakeSurface] = []

  func makeSurface(for content: OverlayContent) -> any OverlaySurface {
    let surface = FakeSurface(kind: content.kind)
    made.append(surface)
    return surface
  }

  func surfaces(of kind: OverlayKind) -> [FakeSurface] {
    made.filter { $0.kind == kind }
  }
}

@MainActor
final class ManualScheduler {
  private var pending: [@MainActor () -> Void] = []

  var schedule: OverlayScheduler {
    { [unowned self] _, work in self.pending.append(work) }
  }

  func runFirst() {
    guard !pending.isEmpty else { return }
    pending.removeFirst()()
  }

  func runAll() {
    let work = pending
    pending.removeAll()
    work.forEach { $0() }
  }
}

@MainActor
final class AnnouncementRecorder {
  private(set) var spoken: [String] = []

  var announce: OverlayAnnouncer {
    { [unowned self] text in self.spoken.append(text) }
  }
}

@MainActor
enum StateManagerStub {
  static func make() -> StateManager {
    let suite = "com.himudigonda.SuperZenTests.stub.\(UUID().uuidString)"
    return StateManager(
      defaults: UserDefaults(suiteName: suite)!, effects: RecordingEffects(),
      locker: FakeLocker(), hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
  }
}

@MainActor
final class FakeActivator: ApplicationActivating {
  let ownProcessID: pid_t = 1
  var isOwnAppActive = false
  var isOwnWindowVisible = false
  var lastExternalProcessID: pid_t?
  var frontmost: pid_t?
  private(set) var activated: [pid_t] = []

  init(frontmost: pid_t?) {
    self.frontmost = frontmost
  }

  func frontmostProcessID() -> pid_t? {
    frontmost
  }

  func activateOwnApp() {
    isOwnAppActive = true
    frontmost = ownProcessID
  }

  func activate(processID: pid_t) {
    activated.append(processID)
    isOwnAppActive = false
    frontmost = processID
  }
}
