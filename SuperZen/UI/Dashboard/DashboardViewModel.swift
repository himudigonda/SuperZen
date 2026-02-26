import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
  // Verifiable Stats
  @Published var currentEyeLoadMinutes: Int = 0
  @Published var longestFocusStreakMinutes: Int = 0
  @Published var focusDensity: Double = 0.0  // Active vs Total

  // Verifiable Wellness Data
  @Published var wellnessSummary: [VerifiableMetric] = []
  @Published var hourlyFocus: [Int: Double] = [:]

  struct VerifiableMetric: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let completed: Int
    let totalPrompted: Int
    let color: Color
  }

  func refresh(context: ModelContext, stateManager: StateManager) {
    let now = Date()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)

    // 1. Live Eye Load (Verifiable via stateManager)
    self.currentEyeLoadMinutes = Int(stateManager.continuousFocusTime / 60)

    // 2. Fetch Sessions for today
    let sessionDescriptor = FetchDescriptor<FocusSession>(
      predicate: #Predicate { $0.startTime >= today })
    let sessions = (try? context.fetch(sessionDescriptor)) ?? []

    let totalActive = sessions.reduce(0.0) { $0 + $1.activeSeconds }
    let totalIdle = sessions.reduce(0.0) { $0 + $1.idleSeconds }

    // Verifiable Density: How much of your 'Focus time' was actually active?
    let totalTime = totalActive + totalIdle
    self.focusDensity = totalTime > 0 ? (totalActive / totalTime) : 0.0

    // Verifiable Streak: Find the session with the most active seconds
    let maxSeconds = sessions.map { $0.activeSeconds }.max() ?? 0.0
    self.longestFocusStreakMinutes = Int(maxSeconds / 60.0)

    // 3. Wellness Verification (Count raw events)
    let eventDescriptor = FetchDescriptor<WellnessEvent>(
      predicate: #Predicate { $0.timestamp >= today })
    let events = (try? context.fetch(eventDescriptor)) ?? []

    self.wellnessSummary = [
      generateMetric(type: .blink, icon: "eye.fill", color: .blue, events: events),
      generateMetric(type: .posture, icon: "figure.stand", color: .pink, events: events),
      generateMetric(type: .water, icon: "drop.fill", color: .cyan, events: events),
    ]

    // 4. Hourly Distribution (Raw minute count per hour)
    var hourly: [Int: Double] = [:]
    for hour in 0..<24 {
      let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
      let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
      let activeInHour = sessions.filter { $0.startTime >= hourStart && $0.startTime < hourEnd }
        .reduce(0.0) { $0 + $1.activeSeconds }
      hourly[hour] = activeInHour / 60.0
    }
    self.hourlyFocus = hourly
  }

  private func generateMetric(
    type: AppStatus.WellnessType, icon: String, color: Color, events: [WellnessEvent]
  ) -> VerifiableMetric {
    let typeEvents = events.filter { $0.type == type.rawValue }
    // "completed" are the ones you actually did. "shown" are total opportunities.
    let completed = typeEvents.filter { $0.action == "completed" }.count
    let total = typeEvents.count
    return VerifiableMetric(
      name: type.rawValue.capitalized, icon: icon, completed: completed, totalPrompted: total,
      color: color)
  }
}
