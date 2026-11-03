import CoreGraphics
import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
final class FakeContext: ContextProviding {
  var current: ContextSample
  private(set) var samples = 0
  private(set) var lastRequested: DeferralSettings?

  init(_ bundleID: String? = nil) {
    current = ContextSample(frontmostBundleID: bundleID)
  }

  func sample(for settings: DeferralSettings) -> ContextSample {
    samples += 1
    lastRequested = settings
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

  @Test func providerReceivesTheCurrentDeferralSettings() {
    defaults.set("us.zoom.xos", forKey: LegacyKey.deferralApps.rawValue)
    defaults.set(false, forKey: LegacyKey.deferralDuringCalls.rawValue)
    defaults.set(true, forKey: LegacyKey.deferralDuringFullscreen.rawValue)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1)
    #expect(context.lastRequested?.apps == ["us.zoom.xos"])
    #expect(context.lastRequested?.duringCalls == false)
    #expect(context.lastRequested?.duringFullscreen == true)
  }

  @Test func activeMicrophoneDefersWithAnEmptyListAndEndsWithTheCall() {
    context.current = ContextSample(frontmostBundleID: "com.apple.dt.Xcode", isMicrophoneInUse: true)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1230)
    #expect(manager.status == .active)
    #expect(manager.menuBar.deferredByApp)
    context.current = ContextSample(frontmostBundleID: "com.apple.dt.Xcode")
    advance(manager, by: 1)
    #expect(manager.status == .onBreak)
  }

  @Test func hardcoreBreakGainsASkipWhenACallStarts() {
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    advance(manager, by: 3)
    #expect(!manager.canSkip)
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos", isMicrophoneInUse: true)
    advance(manager, by: 1)
    #expect(manager.canSkip)
    manager.skipBreak()
    #expect(manager.status == .active)
  }

  @Test func hardcoreBreakStaysLockedWhenCallDeferralIsOff() {
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    defaults.set(false, forKey: LegacyKey.deferralDuringCalls.rawValue)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    context.current = ContextSample(frontmostBundleID: "us.zoom.xos", isMicrophoneInUse: true)
    advance(manager, by: 2)
    #expect(!manager.canSkip)
    manager.skipBreak()
    #expect(manager.status == .onBreak)
  }
}

@MainActor
struct LiveContextProbeTests {
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let microphoneCalls = ProbeLog()
  private let fullscreenCalls = ProbeLog()
  private let frontmostPid = ProbeLog()

  final class ProbeLog {
    var count = 0
    var answer = true
    var pids: [pid_t] = []
  }

  private func makeContext() -> FrontmostContext {
    let microphone = microphoneCalls
    let fullscreen = fullscreenCalls
    let frontmost = frontmostPid
    return FrontmostContext(
      clock: clock,
      frontmost: { ("com.apple.dt.Xcode", frontmost.answer ? 4242 : 4343) },
      microphone: {
        microphone.count += 1
        return microphone.answer
      },
      fullscreen: {
        fullscreen.count += 1
        fullscreen.pids.append($0)
        return fullscreen.answer
      })
  }

  private func settings(calls: Bool, fullscreen: Bool, apps: [String] = []) -> DeferralSettings {
    var settings = DeferralSettings()
    settings.duringCalls = calls
    settings.duringFullscreen = fullscreen
    settings.apps = apps
    return settings
  }

  @Test func bothProbesAreSkippedWhenTheirSwitchesAreOff() {
    let context = makeContext()
    let sample = context.sample(for: settings(calls: false, fullscreen: false, apps: ["us.zoom.xos"]))
    #expect(sample.frontmostBundleID == "com.apple.dt.Xcode")
    #expect(!sample.isMicrophoneInUse)
    #expect(!sample.isFullscreenAppFrontmost)
    #expect(microphoneCalls.count == 0)
    #expect(fullscreenCalls.count == 0)
  }

  @Test func onlyTheEnabledProbeRuns() {
    let context = makeContext()
    let sample = context.sample(for: settings(calls: true, fullscreen: false))
    #expect(sample.isMicrophoneInUse)
    #expect(!sample.isFullscreenAppFrontmost)
    #expect(microphoneCalls.count == 1)
    #expect(fullscreenCalls.count == 0)
  }

  @Test func fullscreenProbeReceivesTheFrontmostPid() {
    let context = makeContext()
    let sample = context.sample(for: settings(calls: false, fullscreen: true))
    #expect(sample.isFullscreenAppFrontmost)
    #expect(fullscreenCalls.pids == [4242])
  }

  @Test func resultsAreCachedForFiveSecondsThenRefreshed() {
    let context = makeContext()
    let both = settings(calls: true, fullscreen: true)
    for _ in 0..<5 {
      _ = context.sample(for: both)
      clock.advance(by: 1)
    }
    #expect(microphoneCalls.count == 1)
    #expect(fullscreenCalls.count == 1)
    microphoneCalls.answer = false
    #expect(context.sample(for: both).isMicrophoneInUse == false)
    #expect(microphoneCalls.count == 2)
    #expect(fullscreenCalls.count == 2)
  }

  @Test func cacheHoldsAStaleAnswerUntilItExpires() {
    let context = makeContext()
    let calls = settings(calls: true, fullscreen: false)
    #expect(context.sample(for: calls).isMicrophoneInUse)
    microphoneCalls.answer = false
    clock.advance(by: 4.9)
    #expect(context.sample(for: calls).isMicrophoneInUse)
    clock.advance(by: 0.1)
    #expect(!context.sample(for: calls).isMicrophoneInUse)
  }

  @Test func clockStepBackDoesNotFreezeTheCache() {
    let context = makeContext()
    let calls = settings(calls: true, fullscreen: false)
    _ = context.sample(for: calls)
    clock.advance(by: -3600)
    _ = context.sample(for: calls)
    #expect(microphoneCalls.count == 2)
  }

  @Test func switchingOffAndOnProbesFresh() {
    let context = makeContext()
    let calls = settings(calls: true, fullscreen: false)
    _ = context.sample(for: calls)
    _ = context.sample(for: settings(calls: false, fullscreen: false))
    _ = context.sample(for: calls)
    #expect(microphoneCalls.count == 2)
  }

  @Test func fullscreenCacheIsPerFrontmostApp() {
    let context = makeContext()
    let fullscreenOnly = settings(calls: false, fullscreen: true)
    _ = context.sample(for: fullscreenOnly)
    frontmostPid.answer = false
    _ = context.sample(for: fullscreenOnly)
    #expect(fullscreenCalls.pids == [4242, 4343])
  }

  @Test func ownProcessIsNeverProbedForFullscreen() {
    let own = ProcessInfo.processInfo.processIdentifier
    let context = FrontmostContext(
      clock: clock, frontmost: { ("com.himudigonda.SuperZen", own) }, microphone: { false },
      fullscreen: { _ in
        Issue.record("own pid was probed")
        return true
      })
    #expect(!context.sample(for: settings(calls: false, fullscreen: true)).isFullscreenAppFrontmost)
  }

  @Test func screenMatchingConvertsToTopLeftCoordinates() {
    let primary = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let external = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
    #expect(
      FullscreenDetector.matches(CGRect(x: 0, y: 0, width: 1512, height: 982), screenFrame: primary, primaryHeight: 982)
    )
    #expect(
      FullscreenDetector.matches(
        CGRect(x: 1512, y: 102, width: 1920, height: 1080), screenFrame: external, primaryHeight: 982))
    #expect(
      !FullscreenDetector.matches(
        CGRect(x: 0, y: 38, width: 1512, height: 944), screenFrame: primary, primaryHeight: 982))
    #expect(
      !FullscreenDetector.matches(
        CGRect(x: 100, y: 100, width: 800, height: 600), screenFrame: primary, primaryHeight: 982))
  }

  @Test func realMicrophoneProbeAnswersWithoutPrompting() {
    _ = MicrophoneActivity.isAnyInputRunning()
  }
}
