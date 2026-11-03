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
  @Published private(set) var menuBar = MenuBarSnapshot.initial

  private(set) var session: SessionState

  private let engine: SessionEngine
  private let clock: any WallClock
  private let defaults: UserDefaults
  private let activity: any ActivityMonitoring
  private let context: any ContextProviding
  private let effects: any SessionEffectPerforming
  private let locker: any ScreenLocking
  let hotkeys: HotkeyCenter
  private var dayProgressWindow: TimeWindow?
  private static let hotkeyRetryInterval = 30
  private var ticksSinceHotkeyRetry = 0
  private var heartbeat: AnyCancellable?
  private var defaultsObserver: AnyCancellable?
  private var systemObserver: SystemActivityObserver?

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
    activity: (any ActivityMonitoring)? = nil,
    context: (any ContextProviding)? = nil,
    effects: (any SessionEffectPerforming)? = nil,
    locker: (any ScreenLocking)? = nil,
    hotkeyRegistrar: (any HotkeyRegistering)? = nil,
    startsAutomatically: Bool = true
  ) {
    SettingsMigrations.run(in: defaults)
    SettingKey.registerDefaults(in: defaults)
    let engine = SessionEngine(calendar: calendar)
    let start = engine.start(settings: Self.loadSettings(from: defaults), at: clock.now)
    self.defaults = defaults
    self.clock = clock
    self.engine = engine
    self.activity = activity ?? SystemActivityMonitor()
    self.context = context ?? FrontmostContext()
    self.locker = locker ?? SystemScreenLocker()
    let performer = effects ?? LiveSessionEffects()
    self.effects = performer
    session = start.state
    dayProgressWindow = Self.loadDayProgressWindow(from: defaults)
    hotkeys = HotkeyCenter(registrar: hotkeyRegistrar ?? CarbonHotkeyRegistrar(), defaults: defaults)
    hotkeys.onAction = { [weak self] action in self?.perform(action) }
    publish()
    start.effects.forEach { performer.perform($0, for: self) }
    if startsAutomatically { startRuntime() }
  }

  func tick() {
    let contextSample = context.sample()
    if contextSample != session.context { send(.context(contextSample)) }
    send(.tick(activity.sample()))
    ticksSinceHotkeyRetry += 1
    guard ticksSinceHotkeyRetry >= Self.hotkeyRetryInterval else { return }
    ticksSinceHotkeyRetry = 0
    hotkeys.reload()
  }

  func startBreak() { send(.startBreak) }
  func skipBreak() { send(.skipBreak) }
  func togglePause() { send(.togglePause) }
  func extendBreak(by seconds: TimeInterval) { send(.extendBreak(seconds)) }
  func snoozeNudge(by seconds: TimeInterval? = nil) { send(.snooze(seconds)) }

  func lockScreen() {
    send(.suspend(.screenLock))
    locker.lock { [weak self] locked in
      guard !locked else { return }
      self?.send(.resume(.screenLock))
    }
  }

  func perform(_ action: HotkeyAction) {
    switch action {
    case .startBreak: startBreak()
    case .togglePause: togglePause()
    case .skipBreak: skipBreak()
    }
  }

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
    if heartbeat != nil { hotkeys.reload() }
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
    hotkeys.reload()
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
    let progress =
      dayProgressWindow.map { DayProgress.compute(window: $0, at: now, calendar: engine.calendar) } ?? .zero
    if dayProgress != progress { dayProgress = progress }
    let snapshot = MenuBarSnapshot(state: session, at: now)
    if menuBar != snapshot { menuBar = snapshot }
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
}
