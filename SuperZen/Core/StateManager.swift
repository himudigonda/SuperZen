import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  // Master Status
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0

  // NEW: Real-time streak tracking (avoids DB latency)
  @Published var continuousFocusTime: TimeInterval = 0

  // Wellness schedules use fixed next-due timestamps to avoid cumulative drift.
  private var nextPostureDue: Date?
  private var nextBlinkDue: Date?
  private var nextWaterDue: Date?
  private var nextAffirmationDue: Date?

  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1500 {
    didSet {
      if status == .active {
        timeRemaining = workDuration
        activeEndsAt = Date().addingTimeInterval(workDuration)
      }
    }
  }
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 300 {
    didSet {
      if status == .onBreak {
        timeRemaining = breakDuration
        breakEndsAt = Date().addingTimeInterval(breakDuration)
      }
    }
  }
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.nudgeLeadTime) var nudgeLeadTime: Double = 10
  @AppStorage(SettingKey.focusIdleThreshold) var idleThreshold: Double = 20
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowWhileTyping: Bool = true
  @AppStorage(SettingKey.focusScheduleEnabled) var focusScheduleEnabled = false
  @AppStorage(SettingKey.focusScheduleStartMinute) var focusScheduleStartMinute = 540
  @AppStorage(SettingKey.focusScheduleEndMinute) var focusScheduleEndMinute = 1080
  @AppStorage(SettingKey.focusScheduleWeekdays) var focusScheduleWeekdays = "2,3,4,5,6"
  @AppStorage(SettingKey.focusScheduleAutoResume) var focusScheduleAutoResume = true
  @AppStorage(SettingKey.quietHoursEnabled) var quietHoursEnabled = false
  @AppStorage(SettingKey.quietHoursStartMinute) var quietHoursStartMinute = 1320
  @AppStorage(SettingKey.quietHoursEndMinute) var quietHoursEndMinute = 420
  @AppStorage(SettingKey.forceResetFocusAfterBreak) var forceResetFocusAfterBreak = true
  @AppStorage(SettingKey.balancedSkipLockRatio) var balancedSkipLockRatio: Double = 0.5
  @AppStorage(SettingKey.wellnessDurationMultiplier) var wellnessDurationMultiplier: Double = 1.0

  @AppStorage("shortcutStartBreak") var shortcutStartBreak = "⌃⌥⌘B" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }
  @AppStorage("shortcutTogglePause") var shortcutTogglePause = "⌃⌥⌘P" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }
  @AppStorage("shortcutSkipBreak") var shortcutSkipBreak = "⌃⌥⌘S" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  /// Seconds the user must wait before they are allowed to skip (Balanced mode).
  private var skipLockDuration: Double {
    let ratio = min(0.9, max(0.1, balancedSkipLockRatio))
    return min(20.0, breakDuration * ratio)
  }

  var canSkip: Bool {
    switch difficulty {
    case .casual: return true
    case .balanced: return timeRemaining <= breakDuration - skipLockDuration
    case .hardcore: return false
    }
  }

  var skipSecondsRemaining: Int {
    max(0, Int(ceil(timeRemaining - (breakDuration - skipLockDuration))))
  }

  private var timer: AnyCancellable?
  private let heartbeatInterval: TimeInterval = 1.0
  private var lastUpdate: Date = Date()
  private var savedWorkTimeRemaining: TimeInterval = 0
  private var preBreakWorkTimeRemaining: TimeInterval = 0
  private var breakStartedAt: Date?
  private var currentWellnessType: AppStatus.WellnessType?
  private var activeEndsAt: Date?
  private var breakEndsAt: Date?
  private var wellnessEndsAt: Date?
  private var schedulePausedByRule = false
  init() {
    // Force initial value from storage
    let initialWork = UserDefaults.standard.double(forKey: SettingKey.workDuration)
    self.timeRemaining = initialWork > 0 ? initialWork : 1500
    start()

    // Register shortcuts on boot
    DispatchQueue.main.async {
      KeyboardShortcutService.shared.setupShortcuts(stateManager: self)
    }
  }

  func start() {
    timer?.cancel()
    lastUpdate = Date()
    if status == .active {
      TelemetryService.shared.startFocusSession()
      if activeEndsAt == nil {
        activeEndsAt = lastUpdate.addingTimeInterval(max(0, timeRemaining))
      }
    } else if status == .onBreak, breakEndsAt == nil {
      breakEndsAt = lastUpdate.addingTimeInterval(max(0, timeRemaining))
    } else if case .wellness = status, wellnessEndsAt == nil {
      wellnessEndsAt = lastUpdate.addingTimeInterval(max(0, timeRemaining))
    }
    timer = Timer.publish(every: heartbeatInterval, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.heartbeat() }
  }

  private func heartbeat() {
    let now = Date()

    if status.isPaused {
      _ = enforceSchedulePolicy(now: now)
      lastUpdate = now
      return
    }
    if enforceSchedulePolicy(now: now) {
      lastUpdate = now
      return
    }

    let delta = now.timeIntervalSince(lastUpdate)
    lastUpdate = now

    // 1. Master Countdown (Active -> Nudge -> Break)
    if status == .active || status == .nudge {
      if activeEndsAt == nil {
        activeEndsAt = now.addingTimeInterval(max(0, timeRemaining))
      }

      let isTyping = dontShowWhileTyping && IdleTracker.getSecondsSinceLastKeyboardInput() < 5.0

      if isTyping {
        // Prevent interruption by freezing the countdown just before the nudge lead time
        if timeRemaining <= nudgeLeadTime + 1.0 {
          activeEndsAt = activeEndsAt?.addingTimeInterval(delta)
        }

        // Push back wellness due dates by delta so they don't expire underneath us
        nextPostureDue = nextPostureDue?.addingTimeInterval(delta)
        nextBlinkDue = nextBlinkDue?.addingTimeInterval(delta)
        nextWaterDue = nextWaterDue?.addingTimeInterval(delta)
        nextAffirmationDue = nextAffirmationDue?.addingTimeInterval(delta)
      }

      let rawRemaining = publishRemaining(until: activeEndsAt, now: now)
      let idleSeconds = IdleTracker.getSecondsSinceLastInput()
      if idleSeconds < idleThreshold {
        continuousFocusTime += delta
        TelemetryService.shared.recordActiveTime(seconds: delta)
      } else {
        TelemetryService.shared.recordIdleTime(seconds: delta, isFocusSession: true)
      }

      // Check for Cursor Nudge transition
      if status == .active && timeRemaining <= nudgeLeadTime {
        transition(to: .nudge)
      }

      // Check for Break transition
      if rawRemaining <= 0 {
        transition(to: .onBreak)
      }

      // 2. Wellness Logic (ONLY while focusing)
      if !isTyping {
        checkWellnessReminders(now: now)
      }
    } else if status == .onBreak {
      if breakEndsAt == nil {
        breakEndsAt = now.addingTimeInterval(max(0, timeRemaining))
      }
      let rawRemaining = publishRemaining(until: breakEndsAt, now: now)
      if rawRemaining <= 0 { transition(to: .active) }
    } else if case .wellness = status {
      if wellnessEndsAt == nil {
        wellnessEndsAt = now.addingTimeInterval(max(0, timeRemaining))
      }
      let rawRemaining = publishRemaining(until: wellnessEndsAt, now: now)
      if rawRemaining <= 0 { transition(to: .active) }
    }
  }

  @discardableResult
  private func enforceSchedulePolicy(now: Date) -> Bool {
    let withinSchedule = SchedulePolicy.isWithinActiveSchedule(
      now: now,
      enabled: focusScheduleEnabled,
      startMinute: focusScheduleStartMinute,
      endMinute: focusScheduleEndMinute,
      weekdaysCSV: focusScheduleWeekdays
    )

    if status == .active || status == .nudge, !withinSchedule {
      schedulePausedByRule = true
      transition(to: .paused)
      return true
    }

    if status == .paused, schedulePausedByRule, focusScheduleAutoResume, withinSchedule {
      schedulePausedByRule = false
      transition(to: .active)
      return true
    }

    return false
  }

  private func remaining(until endDate: Date?, now: Date) -> TimeInterval {
    guard let endDate else { return max(0, timeRemaining) }
    return max(0, endDate.timeIntervalSince(now))
  }

  /// Publish remaining time at 1-second granularity to avoid excessive SwiftUI invalidations.
  private func publishRemaining(until endDate: Date?, now: Date) -> TimeInterval {
    let raw = remaining(until: endDate, now: now)
    let snapped = max(0, ceil(raw))
    if snapped != timeRemaining {
      timeRemaining = snapped
    }
    return raw
  }

  private func checkWellnessReminders(now: Date) {
    let defaults = UserDefaults.standard

    if SchedulePolicy.isWithinQuietHours(
      now: now,
      enabled: quietHoursEnabled,
      startMinute: quietHoursStartMinute,
      endMinute: quietHoursEndMinute
    ) {
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.postureEnabled),
        frequencyKey: SettingKey.postureFrequency, fallback: 600, dueDate: &nextPostureDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.blinkEnabled),
        frequencyKey: SettingKey.blinkFrequency, fallback: 300, dueDate: &nextBlinkDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.waterEnabled),
        frequencyKey: SettingKey.waterFrequency, fallback: 1200, dueDate: &nextWaterDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.affirmationEnabled),
        frequencyKey: SettingKey.affirmationFrequency, fallback: 3600, dueDate: &nextAffirmationDue)
      return
    }

    // Check Posture
    if defaults.bool(forKey: SettingKey.postureEnabled) {
      let freq = defaults.double(forKey: SettingKey.postureFrequency)
      let interval = freq > 0 ? freq : 600
      if shouldFireReminder(now: now, nextDue: &nextPostureDue, interval: interval) {
        transition(to: .wellness(type: .posture))
        return
      }
    } else {
      nextPostureDue = nil
    }

    // Check Blink
    if defaults.bool(forKey: SettingKey.blinkEnabled) {
      let freq = defaults.double(forKey: SettingKey.blinkFrequency)
      let interval = freq > 0 ? freq : 300
      if shouldFireReminder(now: now, nextDue: &nextBlinkDue, interval: interval) {
        transition(to: .wellness(type: .blink))
        return
      }
    } else {
      nextBlinkDue = nil
    }

    // Check Water
    if defaults.bool(forKey: SettingKey.waterEnabled) {
      let freq = defaults.double(forKey: SettingKey.waterFrequency)
      let interval = freq > 0 ? freq : 1200
      if shouldFireReminder(now: now, nextDue: &nextWaterDue, interval: interval) {
        transition(to: .wellness(type: .water))
        return
      }
    } else {
      nextWaterDue = nil
    }

    // Check Affirmation
    if defaults.bool(forKey: SettingKey.affirmationEnabled) {
      let freq = defaults.double(forKey: SettingKey.affirmationFrequency)
      let interval = freq > 0 ? freq : 3600
      if shouldFireReminder(now: now, nextDue: &nextAffirmationDue, interval: interval) {
        transition(to: .wellness(type: .affirmation))
        return
      }
    } else {
      nextAffirmationDue = nil
    }
  }

  private func shouldFireReminder(now: Date, nextDue: inout Date?, interval: TimeInterval) -> Bool {
    if nextDue == nil {
      nextDue = now.addingTimeInterval(interval)
      return false
    }

    guard var due = nextDue, now >= due else { return false }

    // Advance in fixed interval steps so callback jitter does not accumulate.
    repeat {
      due = due.addingTimeInterval(interval)
    } while now >= due
    nextDue = due
    return true
  }

  private func deferReminder(
    now: Date,
    enabled: Bool,
    frequencyKey: String,
    fallback: TimeInterval,
    dueDate: inout Date?
  ) {
    guard enabled else {
      dueDate = nil
      return
    }

    let stored = UserDefaults.standard.double(forKey: frequencyKey)
    let interval = stored > 0 ? stored : fallback
    let candidate = now.addingTimeInterval(interval)
    if let due = dueDate {
      dueDate = due < candidate ? candidate : due
    } else {
      dueDate = candidate
    }
  }

  func transition(to newStatus: AppStatus) {
    if status == newStatus { return }
    let previousStatus = status
    OverlayWindowManager.shared.closeAll()
    logExitEvents(previousStatus: previousStatus, newStatus: newStatus)

    status = newStatus

    switch newStatus {
    case .active:
      schedulePausedByRule = false
      TelemetryService.shared.startFocusSession()
      if case .wellness = previousStatus {
        timeRemaining = savedWorkTimeRemaining
      } else if previousStatus == .onBreak, !forceResetFocusAfterBreak {
        timeRemaining = max(1, preBreakWorkTimeRemaining)
      } else {
        timeRemaining = workDuration
      }
      activeEndsAt = Date().addingTimeInterval(max(0, timeRemaining))
      breakEndsAt = nil
      wellnessEndsAt = nil
    case .nudge:
      OverlayWindowManager.shared.showNudge(with: self)
    case .onBreak:
      TelemetryService.shared.endFocusSession()
      if previousStatus == .active || previousStatus == .nudge {
        preBreakWorkTimeRemaining = remaining(until: activeEndsAt, now: Date())
      }
      breakStartedAt = Date()
      timeRemaining = breakDuration
      activeEndsAt = nil
      breakEndsAt = Date().addingTimeInterval(max(0, breakDuration))
      wellnessEndsAt = nil
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .wellness(let type):
      TelemetryService.shared.endFocusSession()
      if case .wellness = previousStatus {
        // Already in wellness: keep the original savedWorkTimeRemaining.
      } else {
        savedWorkTimeRemaining = remaining(until: activeEndsAt, now: Date())
      }
      currentWellnessType = type
      let multiplier = min(2.0, max(0.75, wellnessDurationMultiplier))
      let duration = type.displayDuration * multiplier
      timeRemaining = duration
      activeEndsAt = nil
      breakEndsAt = nil
      wellnessEndsAt = Date().addingTimeInterval(duration)
      OverlayWindowManager.shared.showWellness(type: type)
      SoundManager.shared.play(.nudge)
    default: break
    }
  }

  /// Extends the current break by `seconds`. Moves the absolute deadline
  /// forward so the heartbeat doesn't immediately undo the change.
  func extendBreak(by seconds: TimeInterval) {
    guard status == .onBreak else { return }
    let now = Date()
    let current = remaining(until: breakEndsAt, now: now)
    let newEnd = now.addingTimeInterval(current + seconds)
    breakEndsAt = newEnd
    timeRemaining = current + seconds
  }

  /// Snoozes the current nudge by adding seconds to the active block length.
  func snoozeNudge(by seconds: TimeInterval = 300) {
    guard status == .nudge else { return }
    OverlayWindowManager.shared.closeAll()
    status = .active
    timeRemaining += seconds
    if let ends = activeEndsAt {
      activeEndsAt = ends.addingTimeInterval(seconds)
    } else {
      activeEndsAt = Date().addingTimeInterval(max(0, timeRemaining))
    }
  }

  func togglePause() {
    if status == .paused {
      schedulePausedByRule = false
      status = .active
      TelemetryService.shared.startFocusSession()
      lastUpdate = Date()
    } else {
      schedulePausedByRule = false
      TelemetryService.shared.endFocusSession()
      activeEndsAt = nil
      breakEndsAt = nil
      wellnessEndsAt = nil
      status = .paused
      OverlayWindowManager.shared.closeAll()
    }
  }

  private func logExitEvents(previousStatus: AppStatus, newStatus: AppStatus) {
    if previousStatus == .onBreak && newStatus == .active {
      let elapsed = breakStartedAt.map { Date().timeIntervalSince($0) } ?? 0
      // Use elapsed time instead of residual countdown to avoid false "skipped" logs
      // when transition timing jitters near zero.
      let completed = elapsed >= max(1.0, breakDuration - 0.5)

      // FIX: Reset the streak ONLY if the break was actually finished
      if completed {
        self.continuousFocusTime = 0
      }

      TelemetryService.shared.logBreak(
        type: "Macro",
        completed: completed,
        duration: max(0, elapsed)
      )
      if !completed {
        TelemetryService.shared.recordSkip()
      }
      breakStartedAt = nil
    }

    if case .wellness = previousStatus, let wellnessType = currentWellnessType {
      let action = newStatus == .active ? "completed" : "dismissed"
      TelemetryService.shared.logWellness(type: wellnessType, action: action)
      currentWellnessType = nil
    }
  }
}
