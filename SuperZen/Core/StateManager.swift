import Combine
import Foundation
import SuperZenCore

@MainActor
final class StateManager: ObservableObject {
  @Published private(set) var status: AppStatus = .active
  @Published private(set) var timeRemaining: TimeInterval = 0
  @Published private(set) var isTyping = false
  @Published private(set) var isScheduleSleeping = false
  @Published private(set) var continuousFocusTime: TimeInterval = 0
  @Published private(set) var canSkip = true
  @Published private(set) var skipSecondsRemaining = 0
  @Published private(set) var dayProgress: DayProgress = .zero
  @Published private(set) var dayProgressEnabled = false

  private(set) var session: SessionState

  private let engine: SessionEngine
  private let clock: any WallClock
  private let defaults: UserDefaults
  private let readActivity: @MainActor () -> ActivitySample
  private let effects: any SessionEffectPerforming
  private var dayProgressWindow: TimeWindow?
  private var heartbeat: AnyCancellable?
  private var defaultsObserver: AnyCancellable?
  private var systemObserver: SystemActivityObserver?
  private var shortcutSignature: [String] = []

  var showTypingIndicator: Bool { isTyping && status == .nudge }
  var difficulty: BreakDifficulty { session.settings.skipPolicy.difficulty }
  var nudgeLeadTime: TimeInterval { session.settings.timer.nudgeLeadTime }
  var breakDuration: TimeInterval { session.currentBreak?.planned ?? session.settings.timer.shortBreakDuration }
  var dayProgressPercent: Double { dayProgress.fraction }
  var dayProgressTimeRemaining: TimeInterval { dayProgress.remaining }
  var dayProgressTimeElapsed: TimeInterval { dayProgress.elapsed }
  var currentTime: Date { clock.now }

  init(
    defaults: UserDefaults = .standard,
    clock: any WallClock = SystemClock(),
    calendar: Calendar = .current,
    activity: @escaping @MainActor () -> ActivitySample = IdleTracker.sample,
    effects: (any SessionEffectPerforming)? = nil,
    startsAutomatically: Bool = true
  ) {
    SettingKey.registerDefaults(in: defaults)
    let engine = SessionEngine(calendar: calendar)
    let start = engine.start(settings: Self.loadSettings(from: defaults), at: clock.now)
    self.defaults = defaults
    self.clock = clock
    self.engine = engine
    self.readActivity = activity
    let performer = effects ?? LiveSessionEffects()
    self.effects = performer
    session = start.state
    dayProgressWindow = Self.loadDayProgressWindow(from: defaults)
    shortcutSignature = Self.shortcuts(in: defaults)
    publish()
    start.effects.forEach { performer.perform($0, for: self) }
    if startsAutomatically { startRuntime() }
  }

  func tick() { send(.tick(readActivity())) }
  func startBreak() { send(.startBreak) }
  func skipBreak() { send(.skipBreak) }
  func togglePause() { send(.togglePause) }
  func extendBreak(by seconds: TimeInterval) { send(.extendBreak(seconds)) }
  func snoozeNudge(by seconds: TimeInterval? = nil) { send(.snooze(seconds)) }

  func send(_ event: SessionEvent) {
    let transition = engine.reduce(session, event, at: clock.now)
    session = transition.state
    publish()
    transition.effects.forEach { effects.perform($0, for: self) }
  }

  func reloadSettings() {
    dayProgressWindow = Self.loadDayProgressWindow(from: defaults)
    let settings = Self.loadSettings(from: defaults)
    if settings != session.settings {
      send(.settingsChanged(settings))
    } else {
      publish()
    }
    let signature = Self.shortcuts(in: defaults)
    if signature != shortcutSignature {
      shortcutSignature = signature
      KeyboardShortcutService.shared.setupShortcuts(stateManager: self)
    }
  }

  private func startRuntime() {
    heartbeat = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.tick() }
    defaultsObserver = NotificationCenter.default
      .publisher(for: UserDefaults.didChangeNotification, object: defaults)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.reloadSettings() }
    systemObserver = SystemActivityObserver { [weak self] event in self?.send(event) }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      KeyboardShortcutService.shared.setupShortcuts(stateManager: self)
    }
  }

  private func publish() {
    let now = clock.now
    let newStatus = AppStatus(phase: session.phase)
    if status != newStatus { status = newStatus }
    let remaining = max(0, ceil(session.remaining(at: now)))
    if timeRemaining != remaining { timeRemaining = remaining }
    if isTyping != session.isTyping { isTyping = session.isTyping }
    if isScheduleSleeping != session.isScheduleSleeping { isScheduleSleeping = session.isScheduleSleeping }
    if continuousFocusTime != session.continuousActive { continuousFocusTime = session.continuousActive }
    let skippable = session.canSkip(at: now)
    if canSkip != skippable { canSkip = skippable }
    let lockSeconds = Int(ceil(session.skipLockRemaining(at: now)))
    if skipSecondsRemaining != lockSeconds { skipSecondsRemaining = lockSeconds }
    let progressEnabled = dayProgressWindow != nil
    if dayProgressEnabled != progressEnabled { dayProgressEnabled = progressEnabled }
    let progress = dayProgressWindow.map { DayProgress.compute(window: $0, at: now, calendar: engine.calendar) } ?? .zero
    if dayProgress != progress { dayProgress = progress }
  }

  private static func loadSettings(from defaults: UserDefaults) -> Settings {
    LegacySettingsMigration.migrate { defaults.object(forKey: $0) }
  }

  private static func loadDayProgressWindow(from defaults: UserDefaults) -> TimeWindow? {
    guard defaults.bool(forKey: SettingKey.dayProgressEnabled) else { return nil }
    return TimeWindow(
      startMinute: defaults.integer(forKey: SettingKey.dayProgressStartMinute),
      endMinute: defaults.integer(forKey: SettingKey.dayProgressEndMinute))
  }

  private static func shortcuts(in defaults: UserDefaults) -> [String] {
    [SettingKey.shortcutStartBreak, SettingKey.shortcutTogglePause, SettingKey.shortcutSkipBreak]
      .map { defaults.string(forKey: $0) ?? "" }
  }
}
