import Foundation
import SwiftData

@MainActor
class TelemetryService {
  static let shared = TelemetryService()

  var modelContext: ModelContext?
  private var currentSession: FocusSession?
  private var deferredSaveScheduled = false
  private let deferredSaveInterval: TimeInterval = 2.0

  struct PruneSummary {
    let sessionsDeleted: Int
    let breaksDeleted: Int
    let wellnessDeleted: Int

    var totalDeleted: Int {
      sessionsDeleted + breaksDeleted + wellnessDeleted
    }
  }

  func setup(context: ModelContext) {
    modelContext = context
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
    save()
    print("Telemetry: Focus session started at \(session.startTime)")
  }

  func endFocusSession() {
    guard let session = currentSession else { return }
    session.endTime = Date()
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
      return PruneSummary(sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0)
    }

    let days = max(1, retainingDays)
    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now

    let sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
    let breaks = (try? modelContext.fetch(FetchDescriptor<BreakEvent>())) ?? []
    let wellness = (try? modelContext.fetch(FetchDescriptor<WellnessEvent>())) ?? []

    let oldSessions = sessions.filter { $0.startTime < cutoff }
    let oldBreaks = breaks.filter { $0.timestamp < cutoff }
    let oldWellness = wellness.filter { $0.timestamp < cutoff }

    for item in oldSessions {
      modelContext.delete(item)
    }
    for item in oldBreaks {
      modelContext.delete(item)
    }
    for item in oldWellness {
      modelContext.delete(item)
    }
    save()

    return PruneSummary(
      sessionsDeleted: oldSessions.count,
      breaksDeleted: oldBreaks.count,
      wellnessDeleted: oldWellness.count
    )
  }

  // MARK: - Private

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
