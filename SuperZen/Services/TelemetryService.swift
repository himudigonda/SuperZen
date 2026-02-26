import AppKit
import Foundation
import SwiftData

@MainActor
class TelemetryService {
  static let shared = TelemetryService()

  var modelContext: ModelContext?
  private var currentSession: FocusSession?
  private var deferredSaveScheduled = false
  private let deferredSaveInterval: TimeInterval = 2.0
  private var workspaceObserver: NSObjectProtocol?
  private var currentBlockID: UUID?
  private var currentBlockStartedAt: Date?
  private var currentAppKey: String?
  private var currentAppName: String?
  private var currentAppStartedAt: Date?
  private var appAccumulators: [String: AppAccumulator] = [:]

  private struct AppAccumulator {
    var appName: String
    var bundleIdentifier: String
    var activeSeconds: Double
    var activationCount: Int
  }

  deinit {
    if let workspaceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
    }
  }

  struct PruneSummary {
    let sessionsDeleted: Int
    let breaksDeleted: Int
    let wellnessDeleted: Int
    let appUsageDeleted: Int

    var totalDeleted: Int {
      sessionsDeleted + breaksDeleted + wellnessDeleted + appUsageDeleted
    }
  }

  func setup(context: ModelContext) {
    modelContext = context
    setupWorkspaceObserverIfNeeded()
    if UserDefaults.standard.bool(forKey: SettingKey.dataRetentionEnabled) {
      let configuredDays = UserDefaults.standard.integer(forKey: SettingKey.dataRetentionDays)
      let days = max(1, configuredDays)
      _ = pruneHistoricalData(retainingDays: days)
    }
  }

  // MARK: - Focus Session Logging

  func startFocusSession() {
    guard currentSession == nil else { return }
    let session = FocusSession()
    modelContext?.insert(session)
    currentSession = session
    startWorkBlockTracking(at: session.startTime)
    save()
    print("Telemetry: Focus session started at \(session.startTime)")
  }

  func endFocusSession() {
    guard let session = currentSession else { return }
    session.endTime = Date()
    endWorkBlockTracking(at: session.endTime ?? Date())
    save()
    print("Telemetry: Focus session ended. Duration: \(Int(session.duration))s")
    currentSession = nil
  }

  func recordActiveTime(seconds: Double) {
    guard let session = currentSession, seconds > 0 else { return }
    session.activeSeconds += seconds
    saveDeferred()
  }

  func recordIdleTime(seconds: Double, isFocusSession: Bool) {
    guard isFocusSession, let session = currentSession, seconds > 0 else { return }
    session.idleSeconds += seconds
    let interruptionThreshold = UserDefaults.standard.double(
      forKey: SettingKey.interruptionThreshold)
    let threshold = interruptionThreshold > 0 ? interruptionThreshold : 30
    if seconds >= threshold {
      session.interruptions += 1
    }
    saveDeferred()
  }

  func recordSkip() {
    guard let session = currentSession else { return }
    session.skips += 1
    save()
  }

  // MARK: - Break Logging

  func logBreak(type: String, completed: Bool, duration: TimeInterval) {
    let event = BreakEvent(type: type, wasCompleted: completed, durationTaken: duration)
    modelContext?.insert(event)
    save()
    let status = completed ? "completed" : "skipped"
    print("Telemetry: Break \(status) — type: \(type), duration: \(Int(duration))s")
  }

  func logWellness(type: AppStatus.WellnessType, action: String) {
    let event = WellnessEvent(type: type.rawValue, action: action)
    modelContext?.insert(event)
    save()
  }

  // MARK: - Analytics

  /// Returns total focused seconds recorded today.
  func getDailyFocusTime() -> TimeInterval {
    let today = Calendar.current.startOfDay(for: Date())
    let descriptor = FetchDescriptor<FocusSession>(
      predicate: #Predicate { $0.startTime >= today }
    )
    let sessions = (try? modelContext?.fetch(descriptor)) ?? []
    return sessions.reduce(0) { $0 + $1.duration }
  }

  /// Returns focused seconds since the most recent completed break.
  /// If no completed break exists, this falls back to today's focused time.
  func getFocusTimeSinceLastCompletedBreak() -> TimeInterval {
    let breakDescriptor = FetchDescriptor<BreakEvent>(
      predicate: #Predicate { $0.wasCompleted == true }
    )
    let breaks = (try? modelContext?.fetch(breakDescriptor)) ?? []
    guard let latestBreak = breaks.max(by: { $0.timestamp < $1.timestamp }) else {
      return getDailyFocusTime()
    }

    let latestBreakTime = latestBreak.timestamp
    let sessionDescriptor = FetchDescriptor<FocusSession>(
      predicate: #Predicate { $0.startTime >= latestBreakTime }
    )
    let sessions = (try? modelContext?.fetch(sessionDescriptor)) ?? []
    return sessions.reduce(0) { $0 + $1.activeSeconds }
  }

  /// Returns number of successfully completed breaks today.
  func getDailyBreaksTaken() -> Int {
    let today = Calendar.current.startOfDay(for: Date())
    let descriptor = FetchDescriptor<BreakEvent>(
      predicate: #Predicate { $0.timestamp >= today && $0.wasCompleted == true }
    )
    return (try? modelContext?.fetch(descriptor))?.count ?? 0
  }

  /// Returns number of skipped breaks today.
  func getDailyBreaksSkipped() -> Int {
    let today = Calendar.current.startOfDay(for: Date())
    let descriptor = FetchDescriptor<BreakEvent>(
      predicate: #Predicate { $0.timestamp >= today && $0.wasCompleted == false }
    )
    return (try? modelContext?.fetch(descriptor))?.count ?? 0
  }

  /// Buckets recent activity into clock hours (0-23) for heatmaps.
  /// Current strategy attributes each session's active seconds to its start hour.
  func getHourlyActivity(daysBack: Int = 7) -> [Int: Double] {
    let calendar = Calendar.current
    let lowerBound = calendar.date(byAdding: .day, value: -max(1, daysBack), to: Date()) ?? Date()
    let descriptor = FetchDescriptor<FocusSession>(
      predicate: #Predicate { $0.startTime >= lowerBound }
    )
    let sessions = (try? modelContext?.fetch(descriptor)) ?? []
    var buckets: [Int: Double] = Dictionary(uniqueKeysWithValues: (0...23).map { ($0, 0) })
    for session in sessions {
      let hour = calendar.component(.hour, from: session.startTime)
      buckets[hour, default: 0] += session.activeSeconds
    }
    return buckets
  }

  @discardableResult
  func pruneHistoricalData(retainingDays: Int, now: Date = Date()) -> PruneSummary {
    guard let modelContext else {
      return PruneSummary(
        sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0, appUsageDeleted: 0)
    }

    let days = max(1, retainingDays)
    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now

    let sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
    let breaks = (try? modelContext.fetch(FetchDescriptor<BreakEvent>())) ?? []
    let wellness = (try? modelContext.fetch(FetchDescriptor<WellnessEvent>())) ?? []
    let appUsage = (try? modelContext.fetch(FetchDescriptor<WorkBlockAppUsage>())) ?? []

    let oldSessions = sessions.filter { $0.startTime < cutoff }
    let oldBreaks = breaks.filter { $0.timestamp < cutoff }
    let oldWellness = wellness.filter { $0.timestamp < cutoff }
    let oldAppUsage = appUsage.filter { $0.blockEnd < cutoff }

    for item in oldSessions {
      modelContext.delete(item)
    }
    for item in oldBreaks {
      modelContext.delete(item)
    }
    for item in oldWellness {
      modelContext.delete(item)
    }
    for item in oldAppUsage {
      modelContext.delete(item)
    }
    save()

    return PruneSummary(
      sessionsDeleted: oldSessions.count,
      breaksDeleted: oldBreaks.count,
      wellnessDeleted: oldWellness.count,
      appUsageDeleted: oldAppUsage.count
    )
  }

  @discardableResult
  func clearAllTelemetryData() -> PruneSummary {
    guard let modelContext else {
      return PruneSummary(
        sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0, appUsageDeleted: 0)
    }

    let sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
    let breaks = (try? modelContext.fetch(FetchDescriptor<BreakEvent>())) ?? []
    let wellness = (try? modelContext.fetch(FetchDescriptor<WellnessEvent>())) ?? []
    let appUsage = (try? modelContext.fetch(FetchDescriptor<WorkBlockAppUsage>())) ?? []

    for item in sessions {
      modelContext.delete(item)
    }
    for item in breaks {
      modelContext.delete(item)
    }
    for item in wellness {
      modelContext.delete(item)
    }
    for item in appUsage {
      modelContext.delete(item)
    }

    currentSession = nil
    resetWorkBlockTrackingState()
    save()

    return PruneSummary(
      sessionsDeleted: sessions.count,
      breaksDeleted: breaks.count,
      wellnessDeleted: wellness.count,
      appUsageDeleted: appUsage.count
    )
  }

  // MARK: - Private

  private func setupWorkspaceObserverIfNeeded() {
    guard workspaceObserver == nil else { return }
    workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      guard self.currentSession != nil else { return }
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else { return }
      self.handleActivatedApplication(app, at: Date())
    }
  }

  private func startWorkBlockTracking(at startedAt: Date) {
    currentBlockID = UUID()
    currentBlockStartedAt = startedAt
    currentAppKey = nil
    currentAppName = nil
    currentAppStartedAt = startedAt
    appAccumulators.removeAll()

    if let app = NSWorkspace.shared.frontmostApplication {
      handleActivatedApplication(app, at: startedAt)
    }
  }

  private func endWorkBlockTracking(at endedAt: Date) {
    finalizeCurrentApp(until: endedAt)

    guard
      let context = modelContext,
      let blockID = currentBlockID,
      let blockStart = currentBlockStartedAt
    else {
      resetWorkBlockTrackingState()
      return
    }

    for accumulator in appAccumulators.values where accumulator.activeSeconds > 0 {
      let row = WorkBlockAppUsage(
        blockID: blockID,
        blockStart: blockStart,
        blockEnd: endedAt,
        appName: accumulator.appName,
        bundleIdentifier: accumulator.bundleIdentifier,
        activeSeconds: accumulator.activeSeconds,
        activationCount: accumulator.activationCount
      )
      context.insert(row)
    }

    resetWorkBlockTrackingState()
  }

  private func handleActivatedApplication(_ app: NSRunningApplication, at timestamp: Date) {
    let appName = sanitizedAppName(from: app)
    let bundleIdentifier = app.bundleIdentifier ?? appName
    let appKey = bundleIdentifier.isEmpty ? appName : bundleIdentifier
    guard !appKey.isEmpty else { return }

    if currentAppKey == appKey {
      return
    }

    finalizeCurrentApp(until: timestamp)

    currentAppKey = appKey
    currentAppName = appName
    currentAppStartedAt = timestamp

    var accumulator =
      appAccumulators[appKey]
      ?? AppAccumulator(
        appName: appName,
        bundleIdentifier: bundleIdentifier,
        activeSeconds: 0,
        activationCount: 0
      )
    accumulator.appName = appName
    accumulator.bundleIdentifier = bundleIdentifier
    accumulator.activationCount += 1
    appAccumulators[appKey] = accumulator
  }

  private func finalizeCurrentApp(until timestamp: Date) {
    guard let appKey = currentAppKey else { return }
    guard let startedAt = currentAppStartedAt else { return }

    let delta = max(0, timestamp.timeIntervalSince(startedAt))
    guard delta > 0 else { return }

    var accumulator =
      appAccumulators[appKey]
      ?? AppAccumulator(
        appName: currentAppName ?? appKey,
        bundleIdentifier: appKey,
        activeSeconds: 0,
        activationCount: 0
      )
    accumulator.activeSeconds += delta
    appAccumulators[appKey] = accumulator
    currentAppStartedAt = timestamp
  }

  private func resetWorkBlockTrackingState() {
    currentBlockID = nil
    currentBlockStartedAt = nil
    currentAppKey = nil
    currentAppName = nil
    currentAppStartedAt = nil
    appAccumulators.removeAll()
  }

  private func sanitizedAppName(from app: NSRunningApplication) -> String {
    let cleaned = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return cleaned.isEmpty ? "Unknown App" : cleaned
  }

  private func save() {
    deferredSaveScheduled = false
    try? modelContext?.save()
  }

  private func saveDeferred() {
    guard !deferredSaveScheduled else { return }
    deferredSaveScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + deferredSaveInterval) { [weak self] in
      guard let self, self.deferredSaveScheduled else { return }
      self.save()
    }
  }
}
