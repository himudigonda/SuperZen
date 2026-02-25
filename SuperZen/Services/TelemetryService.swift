import Foundation
import SwiftData

@MainActor
class TelemetryService {
  static let shared = TelemetryService()

  var modelContext: ModelContext?
  private var currentSession: FocusSession?

  func setup(context: ModelContext) {
    modelContext = context
  }

  // MARK: - Focus Session Logging

  func startFocusSession() {
    let session = FocusSession()
    modelContext?.insert(session)
    currentSession = session
    save()
    print("Telemetry: Focus session started at \(session.startTime)")
  }

  func endFocusSession() {
    guard let session = currentSession else { return }
    let now = Date()
    session.endTime = now
    session.duration = now.timeIntervalSince(session.startTime)
    save()
    print("Telemetry: Focus session ended. Duration: \(Int(session.duration))s")
    currentSession = nil
  }

  // MARK: - Break Logging

  func logBreak(type: String, completed: Bool, duration: TimeInterval) {
    let event = BreakEvent(type: type, wasCompleted: completed, durationTaken: duration)
    modelContext?.insert(event)
    save()
    let status = completed ? "completed" : "skipped"
    print("Telemetry: Break \(status) — type: \(type), duration: \(Int(duration))s")
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

  // MARK: - Private

  private func save() {
    try? modelContext?.save()
  }
}
