import Combine
import Foundation
import SwiftUI

@MainActor
class StateManager: ObservableObject {
  // Master Status
  @Published var status: AppStatus = .active
  @Published var timeRemaining: TimeInterval = 0
  @Published var isTyping: Bool = false

  /// True only during the nudge countdown while the user is typing.
  /// Used exclusively for menu bar display — internal logic uses isTyping directly.
  var showTypingIndicator: Bool { isTyping && status == .nudge }

  // NEW: Real-time streak tracking (avoids DB latency)
  @Published var continuousFocusTime: TimeInterval = 0

  // Wellness schedules use fixed next-due timestamps to avoid cumulative drift.
  private var nextPostureDue: Date?
  private var nextBlinkDue: Date?
  private var nextWaterDue: Date?
  private var nextAffirmationDue: Date?

  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1500
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
  @AppStorage(SettingKey.dayProgressEnabled) var dayProgressEnabled = false
  @AppStorage(SettingKey.dayProgressStartMinute) var dayProgressStartMinute = 540
  @AppStorage(SettingKey.dayProgressEndMinute) var dayProgressEndMinute = 1080
  @AppStorage(SettingKey.quietHoursEnabled) var quietHoursEnabled = false
  @AppStorage(SettingKey.quietHoursStartMinute) var quietHoursStartMinute = 1320
  @AppStorage(SettingKey.quietHoursEndMinute) var quietHoursEndMinute = 420
  @AppStorage(SettingKey.forceResetFocusAfterBreak) var forceResetFocusAfterBreak = true
  @AppStorage(SettingKey.balancedSkipLockRatio) var balancedSkipLockRatio: Double = 0.5
  @AppStorage(SettingKey.wellnessDurationMultiplier) var wellnessDurationMultiplier: Double = 1.0

  @AppStorage(SettingKey.shortcutStartBreak) var shortcutStartBreak = "⌃⌥⌘B" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }
  @AppStorage(SettingKey.shortcutTogglePause) var shortcutTogglePause = "⌃⌥⌘P" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }
  @AppStorage(SettingKey.shortcutSkipBreak) var shortcutSkipBreak = "⌃⌥⌘S" {
    didSet { KeyboardShortcutService.shared.setupShortcuts(stateManager: self) }
  }

  // Track the status before a manual pause so we can restore it correctly on resume.
  private var prePauseStatus: AppStatus = .active

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
  // Tracks the last value seen by refreshSettings() so mid-session duration changes
  // are detected even when @AppStorage already updated (direct UserDefaults writes).
  private var appliedWorkDuration: Double = 0
  private var appliedBreakDuration: Double = 0
  private var wellnessEndsAt: Date?
  private var wellnessDismissToken: UUID?
  @Published var isScheduleSleeping: Bool = false
  @Published var dayProgressPercent: Double = 0
  @Published var dayProgressTimeRemaining: TimeInterval = 0
  @Published var dayProgressTimeElapsed: TimeInterval = 0

  init() {
    // Ensure registered defaults exist before any UserDefaults reads.
    // @StateObject initializers run before App.init(), so we must register here.
    SettingKey.registerDefaults()
    let initialWork = UserDefaults.standard.double(forKey: SettingKey.workDuration)
    self.timeRemaining = initialWork > 0 ? initialWork : 1500
    appliedWorkDuration = self.timeRemaining
    appliedBreakDuration = UserDefaults.standard.double(forKey: SettingKey.breakDuration)
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

  /// Reads all runtime-critical settings fresh from UserDefaults every heartbeat.
  /// @AppStorage on a non-View ObservableObject class does not auto-sync when a Settings
  /// view writes the same key through its own @AppStorage binding. This ensures changes
  /// in Settings take effect immediately rather than requiring an app restart.
  func refreshSettingsForTesting() { refreshSettings() }

  private func refreshSettings() {
    let d = UserDefaults.standard

    let fw = d.double(forKey: SettingKey.workDuration)
    if fw > 0 && fw != appliedWorkDuration {
      let delta = fw - appliedWorkDuration
      appliedWorkDuration = fw
      workDuration = fw
      if status == .active, let ends = activeEndsAt {
        activeEndsAt = ends.addingTimeInterval(delta)
        timeRemaining = max(1, remaining(until: activeEndsAt, now: Date()))
      }
    }

    let fb = d.double(forKey: SettingKey.breakDuration)
    if fb > 0 && fb != appliedBreakDuration {
      let delta = fb - appliedBreakDuration
      appliedBreakDuration = fb
      breakDuration = fb
      if status == .onBreak, let ends = breakEndsAt {
        breakEndsAt = ends.addingTimeInterval(delta)
        timeRemaining = max(1, remaining(until: breakEndsAt, now: Date()))
      }
    }

    let fn = d.double(forKey: SettingKey.nudgeLeadTime)
    if fn > 0 && fn != nudgeLeadTime { nudgeLeadTime = fn }

    let fi = d.double(forKey: SettingKey.focusIdleThreshold)
    if fi > 0 && fi != idleThreshold { idleThreshold = fi }

    let fdr = d.string(forKey: SettingKey.difficulty) ?? BreakDifficulty.balanced.rawValue
    if fdr != difficultyRaw { difficultyRaw = fdr }

    let fdt = d.bool(forKey: SettingKey.dontShowWhileTyping)
    if fdt != dontShowWhileTyping { dontShowWhileTyping = fdt }

    let fse = d.bool(forKey: SettingKey.focusScheduleEnabled)
    if fse != focusScheduleEnabled { focusScheduleEnabled = fse }

    let fsst = d.integer(forKey: SettingKey.focusScheduleStartMinute)
    if fsst != focusScheduleStartMinute { focusScheduleStartMinute = fsst }

    let fset = d.integer(forKey: SettingKey.focusScheduleEndMinute)
    if fset != focusScheduleEndMinute { focusScheduleEndMinute = fset }

    let fsw = d.string(forKey: SettingKey.focusScheduleWeekdays) ?? "2,3,4,5,6"
    if fsw != focusScheduleWeekdays { focusScheduleWeekdays = fsw }

    let fsar = d.bool(forKey: SettingKey.focusScheduleAutoResume)
    if fsar != focusScheduleAutoResume { focusScheduleAutoResume = fsar }

    let fdpe = d.bool(forKey: SettingKey.dayProgressEnabled)
    if fdpe != dayProgressEnabled { dayProgressEnabled = fdpe }

    let fdps = d.integer(forKey: SettingKey.dayProgressStartMinute)
    if fdps != dayProgressStartMinute { dayProgressStartMinute = fdps }

    let fdpE = d.integer(forKey: SettingKey.dayProgressEndMinute)
    if fdpE != dayProgressEndMinute { dayProgressEndMinute = fdpE }

    let fqhe = d.bool(forKey: SettingKey.quietHoursEnabled)
    if fqhe != quietHoursEnabled { quietHoursEnabled = fqhe }

    let fqhs = d.integer(forKey: SettingKey.quietHoursStartMinute)
    if fqhs != quietHoursStartMinute { quietHoursStartMinute = fqhs }

    let fqhE = d.integer(forKey: SettingKey.quietHoursEndMinute)
    if fqhE != quietHoursEndMinute { quietHoursEndMinute = fqhE }

    let ffr = d.bool(forKey: SettingKey.forceResetFocusAfterBreak)
    if ffr != forceResetFocusAfterBreak { forceResetFocusAfterBreak = ffr }

    let fbs = d.double(forKey: SettingKey.balancedSkipLockRatio)
    if fbs > 0 && fbs != balancedSkipLockRatio { balancedSkipLockRatio = fbs }

    let fwdm = d.double(forKey: SettingKey.wellnessDurationMultiplier)
    if fwdm > 0 && fwdm != wellnessDurationMultiplier { wellnessDurationMultiplier = fwdm }
  }

  private func heartbeat() {
    let now = Date()
    refreshSettings()

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

      let typing = dontShowWhileTyping && IdleTracker.getSecondsSinceLastKeyboardInput() < 5.0
      if typing != isTyping { isTyping = typing }

      if typing {
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

      // 2. Wellness Logic (ONLY during active focus, not during the nudge countdown)
      if !typing && status == .active {
        checkWellnessReminders(now: now)
      }
    } else if status == .onBreak {
      if isTyping { isTyping = false }
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

    updateDayProgress()
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
      isScheduleSleeping = true
      transition(to: .paused)
      return true
    }

    if status == .paused, isScheduleSleeping, focusScheduleAutoResume, withinSchedule {
      isScheduleSleeping = false
      transition(to: .active)
      return true
    }

    return false
  }

  private func remaining(until endDate: Date?, now: Date) -> TimeInterval {
    guard let endDate else { return max(0, timeRemaining) }
    return max(0, endDate.timeIntervalSince(now))
  }

  private func remainingForCurrentState(at now: Date) -> TimeInterval {
    switch status {
    case .active, .nudge:
      return remaining(until: activeEndsAt, now: now)
    case .onBreak:
      return remaining(until: breakEndsAt, now: now)
    case .wellness:
      return remaining(until: wellnessEndsAt, now: now)
    case .paused:
      return max(0, timeRemaining)
    }
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
        frequencyKey: SettingKey.postureFrequency, fallback: 1200, dueDate: &nextPostureDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.blinkEnabled),
        frequencyKey: SettingKey.blinkFrequency, fallback: 1200, dueDate: &nextBlinkDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.waterEnabled),
        frequencyKey: SettingKey.waterFrequency, fallback: 3600, dueDate: &nextWaterDue)
      deferReminder(
        now: now, enabled: defaults.bool(forKey: SettingKey.affirmationEnabled),
        frequencyKey: SettingKey.affirmationFrequency, fallback: 3600, dueDate: &nextAffirmationDue)
      return
    }

    // Check Posture
    if defaults.bool(forKey: SettingKey.postureEnabled) {
      let freq = defaults.double(forKey: SettingKey.postureFrequency)
      let interval = freq > 0 ? freq : 1200
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
      let interval = freq > 0 ? freq : 1200
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
      let interval = freq > 0 ? freq : 3600
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

  private func updateDayProgress() {
    guard dayProgressEnabled else {
      dayProgressPercent = 0
      dayProgressTimeRemaining = 0
      dayProgressTimeElapsed = 0
      return
    }

    let now = Date()
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    var startComps = comps
    startComps.hour = dayProgressStartMinute / 60
    startComps.minute = dayProgressStartMinute % 60
    startComps.second = 0

    var endComps = comps
    endComps.hour = dayProgressEndMinute / 60
    endComps.minute = dayProgressEndMinute % 60
    endComps.second = 0

    guard let dayStart = cal.date(from: startComps),
      let dayEnd = cal.date(from: endComps),
      dayEnd > dayStart
    else {
      dayProgressPercent = 0
      dayProgressTimeRemaining = 0
      dayProgressTimeElapsed = 0
      return
    }

    let total = dayEnd.timeIntervalSince(dayStart)
    let elapsed = now.timeIntervalSince(dayStart)
    dayProgressPercent = max(0, min(1, elapsed / total))
    dayProgressTimeRemaining = max(0, dayEnd.timeIntervalSince(now))
    dayProgressTimeElapsed = max(0, elapsed)
  }

  func transition(to newStatus: AppStatus) {
    if status == newStatus { return }
    let previousStatus = status
    OverlayWindowManager.shared.closeAll()
    logExitEvents(previousStatus: previousStatus, newStatus: newStatus)

    status = newStatus

    if newStatus != .active && newStatus != .nudge {
      isTyping = false
    }

    switch newStatus {
    case .active:
      isScheduleSleeping = false
      // startFocusSession is guarded by currentSession == nil.
      // After a skipped break or nudge, the session was ended in logExitEvents,
      // so this always starts a fresh work block.
      TelemetryService.shared.startFocusSession()
      if case .wellness = previousStatus {
        timeRemaining = savedWorkTimeRemaining
      } else if previousStatus == .nudge {
        // User skipped the upcoming break from the nudge popup.
        // The work timer had expired, so start a fresh work block.
        timeRemaining = workDuration
      } else if previousStatus == .onBreak {
        if forceResetFocusAfterBreak {
          timeRemaining = workDuration
        } else {
          timeRemaining = max(1, preBreakWorkTimeRemaining)
        }
        SoundManager.shared.play(.breakEnd)
      } else {
        timeRemaining = workDuration
      }
      activeEndsAt = Date().addingTimeInterval(max(0, timeRemaining))
      breakEndsAt = nil
      wellnessEndsAt = nil
      wellnessDismissToken = nil
    case .nudge:
      OverlayWindowManager.shared.showNudge(with: self)
      wellnessDismissToken = nil
    case .onBreak:
      // Don't end the focus session here — defer to logExitEvents so that
      // skipping a break keeps the session alive for continuity.
      if previousStatus == .active || previousStatus == .nudge {
        preBreakWorkTimeRemaining = remaining(until: activeEndsAt, now: Date())
      }
      breakStartedAt = Date()
      timeRemaining = breakDuration
      activeEndsAt = nil
      breakEndsAt = Date().addingTimeInterval(max(0, breakDuration))
      wellnessEndsAt = nil
      wellnessDismissToken = nil
      OverlayWindowManager.shared.showBreak(with: self)
      SoundManager.shared.play(.breakStart)
    case .wellness(let type):
      // Don't end the focus session during short wellness reminders.
      // The session continues seamlessly across them.
      if case .wellness = previousStatus {
        // Already in wellness: keep the original savedWorkTimeRemaining.
      } else {
        savedWorkTimeRemaining = remaining(until: activeEndsAt, now: Date())
      }
      currentWellnessType = type
      let multiplier = min(2.0, max(0.1, wellnessDurationMultiplier))
      let duration = type.displayDuration * multiplier
      timeRemaining = duration
      activeEndsAt = nil
      breakEndsAt = nil
      wellnessEndsAt = Date().addingTimeInterval(duration)
      OverlayWindowManager.shared.showWellness(type: type)
      SoundManager.shared.play(.nudge)

      // Schedule precise dismissal via DispatchQueue to avoid 1-second heartbeat latency
      let token = UUID()
      wellnessDismissToken = token
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
        guard let self, self.wellnessDismissToken == token else { return }
        self.transition(to: .active)
      }
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
      let now = Date()
      let resumedDuration = max(1, remainingForCurrentState(at: now))
      isScheduleSleeping = false
      wellnessDismissToken = nil
      lastUpdate = now

      if prePauseStatus == .onBreak {
        status = .onBreak
        timeRemaining = resumedDuration
        breakEndsAt = now.addingTimeInterval(max(0, resumedDuration))
        activeEndsAt = nil
        wellnessEndsAt = nil
        OverlayWindowManager.shared.showBreak(with: self)
      } else {
        status = .active
        TelemetryService.shared.startFocusSession()
        timeRemaining = resumedDuration
        activeEndsAt = now.addingTimeInterval(max(0, resumedDuration))
        breakEndsAt = nil
        wellnessEndsAt = nil
      }
      start()
    } else {
      let now = Date()
      prePauseStatus = status
      isScheduleSleeping = false
      TelemetryService.shared.endFocusSession()
      timeRemaining = max(1, remainingForCurrentState(at: now))
      activeEndsAt = nil
      breakEndsAt = nil
      wellnessEndsAt = nil
      wellnessDismissToken = nil
      status = .paused
      lastUpdate = now
      OverlayWindowManager.shared.closeAll()
    }
  }

  private func logExitEvents(previousStatus: AppStatus, newStatus: AppStatus) {
    if previousStatus == .onBreak && newStatus == .active {
      let elapsed = breakStartedAt.map { Date().timeIntervalSince($0) } ?? 0
      // Use elapsed time instead of residual countdown to avoid false "skipped" logs
      // when transition timing jitters near zero.
      let completed = elapsed >= max(1.0, breakDuration - 0.5)

      // Always end the focus session — whether break was completed or skipped.
      // This closes the current work block and saves it. When skipped, the
      // .active case will call startFocusSession() to begin a fresh new block.
      TelemetryService.shared.endFocusSession()
      self.continuousFocusTime = 0

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

    // Skipping from the nudge popup (work timer expired, user dismissed break).
    // End the current work block so the new .active state starts a fresh block.
    if previousStatus == .nudge && newStatus == .active {
      TelemetryService.shared.endFocusSession()
      self.continuousFocusTime = 0
    }

    if case .wellness = previousStatus, let wellnessType = currentWellnessType {
      let action = newStatus == .active ? "completed" : "dismissed"
      TelemetryService.shared.logWellness(type: wellnessType, action: action)
      currentWellnessType = nil
    }
  }
}
