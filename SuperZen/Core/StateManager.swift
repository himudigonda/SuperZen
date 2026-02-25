import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  // Skip Enforcement Properties (driven by difficulty setting)
  @Published var canSkip: Bool = false
  @Published var skipSecondsRemaining: Int = 0

  /// Observers to fix the "Real-time Reflection" bug
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1200 {
    didSet { if status == .active { adjustTimer(old: oldValue, new: workDuration) } }
  }

  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 60 {
    didSet { if status == .onBreak { adjustTimer(old: oldValue, new: breakDuration) } }
  }

  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.breakCounter) var breakCounter: Int = 0
  @AppStorage(SettingKey.longBreakEvery) var longBreakEvery: Int = 4
  @AppStorage(SettingKey.longBreakDuration) var longBreakDuration: Double = 300

  // Logic Hooks from the Settings Page
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowTyping = true
  @AppStorage(SettingKey.lockMacAutomatically) var lockMac = false
  @AppStorage(SettingKey.reminderAdvanceTime) var nudgeLeadTime: Double = 60  // seconds

  private var lastUpdate: Date = .init()
  private var timer: AnyCancellable?

  init() {
    timeRemaining = workDuration
    start()
  }

  private func adjustTimer(old: Double, new: Double) {
    let elapsed = old - timeRemaining
    timeRemaining = max(0, new - elapsed)
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
    timer = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.heartbeat() }
  }

  private func heartbeat() {
    let now = Date()
    let delta = now.timeIntervalSince(lastUpdate)
    lastUpdate = now

    // 1. Check Smart Pause Conditions (Intelligent Awareness)
    if handleSmartPause() { return }

    // 2. Normal Ticking
    if status.isPaused || status == .idle { return }

    // 3. Check if user is actively typing/dragging (< 1s since last input)
    let isUserBusy = IdleTracker.getSecondsSinceLastInput() < 1.0

    timeRemaining -= delta

    // 4. Enforce Skip Difficulty
    if status == .onBreak {
      updateSkipLogic(delta: delta)
    }

    // 5. Automatic Transitions
    // Transition to nudge when time is low, using dynamic nudgeLeadTime
    if status == .active, timeRemaining <= nudgeLeadTime, timeRemaining > 0 {
      status = .nudge
      OverlayWindowManager.shared.showNudge(with: self)
    }

    // 6. Handle break transition with anti-interruption
    if timeRemaining <= 0 {
      if dontShowTyping && isUserBusy && status == .nudge {
        // User is typing! Hold the break for 5 seconds and check again
        timeRemaining = 5
        return
      }
      autoTransition()
    }
  }

  private func handleSmartPause() -> Bool {
    let pauseMeetings = UserDefaults.standard.bool(forKey: SettingKey.pauseMeetings)
    let pauseGaming = UserDefaults.standard.bool(forKey: SettingKey.pauseGaming)

    if pauseMeetings && SystemHooks.shared.isMediaInUse() {
      if status != .paused(reason: .meeting) { transition(to: .paused(reason: .meeting)) }
      return true
    }

    if pauseGaming && SystemHooks.shared.isFullscreenAppActive() {
      if status != .paused(reason: .fullscreen) { transition(to: .paused(reason: .fullscreen)) }
      return true
    }

    // Auto-resume if the meeting/game ended
    if case .paused(let reason) = status, reason == .meeting || reason == .fullscreen {
      transition(to: .active)
    }

    return false
  }

  func transition(to newStatus: AppStatus, isLong: Bool = false) {
    if status == newStatus { return }
    OverlayWindowManager.shared.closeAll()

    status = newStatus
    lastUpdate = Date()

    // Pre-calculate skip state immediately (prevents "Locked" flicker)
    canSkip = (difficulty == .casual)
    skipSecondsRemaining = (difficulty == .balanced) ? 5 : 0
    if difficulty == .hardcore { skipSecondsRemaining = 99 }

    switch newStatus {
    case .active:
      timeRemaining = workDuration
      TelemetryService.shared.startFocusSession()
    case .onBreak:
      // Hook: Lock Mac Automatically
      if lockMac { lockSystem() }

      timeRemaining = isLong ? longBreakDuration : breakDuration
      // Force logic update for the very first frame
      updateSkipLogic(delta: 0)
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .nudge:
      if timeRemaining > nudgeLeadTime {
        timeRemaining = nudgeLeadTime
      }
      OverlayWindowManager.shared.showNudge(with: self)
    case .paused, .idle:
      TelemetryService.shared.endFocusSession()
    }
  }

  func togglePause() {
    if status.isPaused {
      transition(to: .active)
    } else {
      transition(to: .paused(reason: .manual))
    }
  }

  func snooze() {
    OverlayWindowManager.shared.closeAll()
    timeRemaining += 300
    status = .active
    lastUpdate = Date()
  }

  private func autoTransition() {
    if status == .active || status == .nudge {
      breakCounter += 1
      let isLong = (longBreakEvery > 0 && breakCounter % longBreakEvery == 0)
      transition(to: .onBreak, isLong: isLong)
    } else if status == .onBreak {
      transition(to: .active)
      SoundManager.shared.play(.breakEnd)
    }
  }

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  private func updateSkipLogic(delta _: TimeInterval) {
    switch difficulty {
    case .casual:
      canSkip = true
      skipSecondsRemaining = 0
    case .balanced:
      let totalBreak =
        (longBreakEvery > 0 && breakCounter % longBreakEvery == 0)
        ? longBreakDuration : breakDuration
      let elapsed = totalBreak - timeRemaining

      // BUG FIX: The wait time should not be longer than the break itself
      let requiredWait = min(5.0, totalBreak)

      let remaining = requiredWait - elapsed
      skipSecondsRemaining = Int(max(0, ceil(remaining)))
      canSkip = elapsed >= requiredWait
    case .hardcore:
      canSkip = false
      skipSecondsRemaining = 99  // Signals "locked" to the UI
    }
  }

  /// Lock the Mac screen when a break starts (if enabled)
  private func lockSystem() {
    let libPath = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
    guard let lib = dlopen(libPath, RTLD_NOW) else { return }
    guard let sym = dlsym(lib, "SACLockScreenImmediate") else {
      dlclose(lib)
      return
    }
    typealias LockFunc = @convention(c) () -> Void
    let lock = unsafeBitCast(sym, to: LockFunc.self)
    lock()
    dlclose(lib)
  }
}
