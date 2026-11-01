import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

final class ManualClock: WallClock, @unchecked Sendable {
  var now: Date

  init(_ now: Date) {
    self.now = now
  }

  func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }
}

@MainActor
final class RecordingEffects: SessionEffectPerforming {
  var performed: [SessionEffect] = []

  func perform(_ effect: SessionEffect, for manager: StateManager) {
    performed.append(effect)
  }
}

@MainActor
@Suite(.serialized)
struct StateManagerTests {
  private let suiteName = "com.himudigonda.SuperZenTests.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let clock = ManualClock(Date(timeIntervalSince1970: 1_793_620_800))
  private let effects = RecordingEffects()
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
    for key in [SettingKey.postureEnabled, SettingKey.blinkEnabled, SettingKey.waterEnabled, SettingKey.affirmationEnabled] {
      defaults.set(false, forKey: key)
    }
  }

  private func makeManager(
    activity: ScriptedActivity? = nil, locker: FakeLocker? = nil
  ) -> StateManager {
    StateManager(
      defaults: defaults, clock: clock, calendar: calendar, activity: activity ?? ScriptedActivity(),
      effects: effects, locker: locker ?? FakeLocker(), hotkeyRegistrar: FakeHotkeyRegistrar(), startsAutomatically: false)
  }

  private func advance(_ manager: StateManager, by seconds: Int) {
    for _ in 0..<seconds {
      clock.advance(by: 1)
      manager.tick()
    }
  }

  @Test func startsFocusingWithTwentyMinuteDefault() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(manager.status == .active)
    #expect(manager.timeRemaining == 1200)
    #expect(effects.performed == [.telemetry(.focusStarted)])
  }

  @Test func ticksDriveNudgeAndBreakWithSkipLock() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 1190)
    #expect(manager.status == .nudge)
    #expect(effects.performed.contains(.showNudge))
    advance(manager, by: 10)
    #expect(manager.status == .onBreak)
    #expect(manager.timeRemaining == 20)
    #expect(manager.canSkip == false)
    #expect(manager.skipSecondsRemaining == 10)
    manager.skipBreak()
    #expect(manager.status == .onBreak)
    advance(manager, by: 10)
    manager.skipBreak()
    #expect(manager.status == .active)
    #expect(manager.timeRemaining == 1200)
  }

  @Test func legacyUserDefaultsAreHonored() {
    defaults.set(1500.0, forKey: SettingKey.workDuration)
    defaults.set(BreakDifficulty.hardcore.rawValue, forKey: SettingKey.difficulty)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(manager.timeRemaining == 1500)
    #expect(manager.difficulty == .hardcore)
  }

  @Test func settingsChangesApplyWithoutRestart() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 60)
    defaults.set(600.0, forKey: SettingKey.workDuration)
    manager.reloadSettings()
    #expect(manager.timeRemaining == 600)
  }

  @Test func longSleepComesBackToFreshFocusNotABreak() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    advance(manager, by: 300)
    manager.send(.suspend(.sleep))
    #expect(manager.status == .paused)
    clock.advance(by: 3600)
    manager.send(.resume(.sleep))
    #expect(manager.status == .active)
    #expect(manager.timeRemaining == 1200)
    #expect(!effects.performed.contains(.showBreak(.short)))
  }

  @Test func typingIndicatorShowsOnlyWhileDeferringBreak() {
    let activity = ScriptedActivity()
    let manager = makeManager(activity: activity)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    activity.current = .typing
    advance(manager, by: 1100)
    #expect(manager.isTyping)
    #expect(manager.showTypingIndicator == false)
    advance(manager, by: 110)
    #expect(manager.status == .nudge)
    #expect(manager.showTypingIndicator)
  }

  @Test func dayProgressFollowsSettings() {
    defaults.set(true, forKey: SettingKey.dayProgressEnabled)
    defaults.set(0, forKey: SettingKey.dayProgressStartMinute)
    defaults.set(1440 - 1, forKey: SettingKey.dayProgressEndMinute)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(manager.dayProgressEnabled)
    #expect(manager.dayProgressPercent > 0.5 && manager.dayProgressPercent < 0.51)
    defaults.set(false, forKey: SettingKey.dayProgressEnabled)
    manager.reloadSettings()
    #expect(manager.dayProgressEnabled == false)
    #expect(manager.dayProgressPercent == 0)
  }

  @Test func scheduleSleepIsReportedForMenuBar() {
    defaults.set(true, forKey: SettingKey.focusScheduleEnabled)
    defaults.set("", forKey: SettingKey.focusScheduleWeekdays)
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.tick()
    #expect(manager.isScheduleSleeping)
    #expect(manager.status == .paused)
  }

  @Test func engineKeysMatchLegacySettingKeys() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let known = Set(SettingKey.allKeys)
    for key in LegacyKey.allCases {
      #expect(known.contains(key.rawValue), "\(key.rawValue) missing from SettingKey.allKeys")
    }
  }

  @Test func lockHidesTheBreakBeforeLockingAndWaitsForUnlock() {
    let locker = FakeLocker(outcome: true)
    let manager = makeManager(locker: locker)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    manager.lockScreen()
    #expect(locker.attempts == 1)
    #expect(manager.status == .paused)
    #expect(effects.performed.contains(.hideOverlays))
    clock.advance(by: 5)
    manager.send(.resume(.screenLock))
    #expect(manager.status == .onBreak)
  }

  @Test func failedLockResumesTheBreakImmediately() {
    let manager = makeManager(locker: FakeLocker(outcome: false))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.startBreak()
    effects.performed.removeAll()
    manager.lockScreen()
    #expect(manager.status == .onBreak)
    #expect(effects.performed.contains(.hideOverlays))
    #expect(effects.performed.contains(.showBreak(.short)))
  }

  @Test func confirmedLockIgnoresLaterSystemLockEvents() {
    let manager = makeManager(locker: FakeLocker(outcome: true))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.lockScreen()
    manager.send(.suspend(.screenLock))
    manager.send(.resume(.screenLock))
    #expect(manager.status == .active)
  }

  @Test func hotkeyActionsDriveTheSession() {
    let manager = makeManager()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    manager.perform(.startBreak)
    #expect(manager.status == .onBreak)
    manager.perform(.togglePause)
    #expect(manager.status == .paused)
    manager.perform(.togglePause)
    #expect(manager.status == .onBreak)
  }

  @Test func naturalBreakStillReadsAsFocusing() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    #expect(AppStatus(phase: .naturalBreak(since: clock.now)) == .active)
    #expect(SettingsCatalog.workDurationDefault == 1200)
    #expect(SettingsCatalog.breakDurationDefault == 20)
  }
}
