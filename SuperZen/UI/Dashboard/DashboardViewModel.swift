import Combine
import Foundation
import SwiftData
import SwiftUI

// MARK: - Chart Data Models

struct DailyFocus: Identifiable {
  let id = UUID()
  let date: Date
  let seconds: TimeInterval
}

struct ComplianceData: Identifiable {
  let id = UUID()
  let status: String
  let count: Int
  let color: Color
}

// MARK: - ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
  @Published var weeklyFocus: [DailyFocus] = []
  @Published var compliance: [ComplianceData] = []
  @Published var totalToday: TimeInterval = 0
  @Published var breaksTakenToday: Int = 0
  @Published var breaksSkippedToday: Int = 0

  func refresh(context: ModelContext) {
    let calendar = Calendar.current
    let now = Date()

    // --- Weekly Focus ---
    var dailyStats: [DailyFocus] = []
    for idx in (0...6).reversed() {
      let day = calendar.date(byAdding: .day, value: -idx, to: now) ?? now
      let start = calendar.startOfDay(for: day)
      let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

      let descriptor = FetchDescriptor<FocusSession>(
        predicate: #Predicate { $0.startTime >= start && $0.startTime < end }
      )
      let sessions = (try? context.fetch(descriptor)) ?? []
      let total = sessions.reduce(0) { $0 + $1.duration }
      dailyStats.append(DailyFocus(date: start, seconds: total))

      if idx == 0 { totalToday = total }
    }
    weeklyFocus = dailyStats

    // --- Break Compliance (Today) ---
    let today = calendar.startOfDay(for: now)
    let breakDescriptor = FetchDescriptor<BreakEvent>(
      predicate: #Predicate { $0.timestamp >= today }
    )
    let events = (try? context.fetch(breakDescriptor)) ?? []
    let taken = events.filter { $0.wasCompleted }.count
    let skipped = events.filter { !$0.wasCompleted }.count

    breaksTakenToday = taken
    breaksSkippedToday = skipped

    compliance = [
      ComplianceData(status: "Taken", count: taken, color: .green),
      // swiftlint:disable:next trailing_comma
      ComplianceData(status: "Skipped", count: skipped, color: .orange),
    ]
  }
}
