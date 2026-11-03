import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
final class FakeContext: ContextProviding {
  var current: ContextSample
  private(set) var samples = 0

  init(_ bundleID: String? = nil) {
    current = ContextSample(frontmostBundleID: bundleID)
  }

  func sample() -> ContextSample {
    samples += 1
    return current
  }
}

@MainActor
@Suite(.serialized)
struct DeferralContextTests {
  private let suiteName = "com.himudigonda.SuperZenTests.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let effects = RecordingEffects()
  private let context = FakeContext()

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
      defaults: defaults, clock: clock, calendar: calendar, activity: ScriptedActivity(), context: context,
      effects: effects, locker: FakeLocker(), hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
  }

  private func advance(_ manager: StateManager, by seconds: Int) {
    for _ in 0..<seconds {
      clock.advance(by: 1)
      manager.tick()
    }
  }

  @Test func everyTickSamplesTheProviderOnce() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 5)
    #expect(context.samples == 5)
  }

  @Test func sampleReachesTheEngineAndFollowsChanges() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(manager.session.context == .unknown)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos")
    advance(manager, by: 1)
    #expect(manager.session.context.frontmostBundleID == "us.zoom.xos")
    advance(manager, by: 3)
    #expect(manager.session.context.frontmostBundleID == "us.zoom.xos")
    context.current = ContextSample(frontmostBundleID: nil)
    advance(manager, by: 1)
    #expect(manager.session.context == .unknown)
  }

  @Test func contextEventPrecedesTheTickThatUsesIt() {
    defaults.set("us.zoom.xos", forKey: LegacyKey.deferralApps.rawValue)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos")
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1195)
    #expect(manager.status == .active)
    #expect(!effects.performed.contains(.showNudge))
    advance(manager, by: 10)
    #expect(manager.status == .active)
    #expect(manager.menuBar.deferredByApp)
    context.current = ContextSample(frontmostBundleID: "com.apple.dt.Xcode")
    advance(manager, by: 1)
    #expect(manager.status == .onBreak)
    #expect(!manager.menuBar.deferredByApp)
  }

  @Test func unlistedAppsNeverDefer() {
    defaults.set("us.zoom.xos", forKey: LegacyKey.deferralApps.rawValue)
    context.current = ContextSample(frontmostBundleID: "com.apple.dt.Xcode")
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1190)
    #expect(manager.status == .nudge)
    #expect(!manager.menuBar.deferredByApp)
  }

  @Test func capEndsDeferralEvenWithTheAppStillFrontmost() {
    defaults.set("us.zoom.xos", forKey: LegacyKey.deferralApps.rawValue)
    defaults.set(60.0, forKey: LegacyKey.deferralCap.rawValue)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos")
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1259)
    #expect(manager.status == .active)
    advance(manager, by: 1)
    #expect(manager.status == .onBreak)
  }
}
