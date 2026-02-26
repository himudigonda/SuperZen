import Combine
import Foundation
import SwiftData
import SwiftUI

struct DailyFocus: Identifiable {
  let id = UUID()
  let date: Date
  let minutes: Double
}

struct WellnessCadence: Identifiable {
  let id = UUID()
  let title: String
  let icon: String
  let shown: Int
  let targetMinutes: Int
  let status: String
  let progress: Double
  let color: Color
}

private struct WellnessMetricConfig {
  let type: AppStatus.WellnessType
  let title: String
  let icon: String
  let frequencyKey: String
  let enabledKey: String
  let color: Color
}

@MainActor
class DashboardViewModel: ObservableObject {
  @Published var weeklyFocus: [DailyFocus] = []
  @Published var hourlyFocusToday: [Int: Double] = Dictionary(
    uniqueKeysWithValues: (0...23).map { ($0, 0) })
  @Published var wellnessCadence: [WellnessCadence] = []

  @Published var bioScore: Int = 0
  @Published var summary: String = "Start a focus session to generate Insights."

  @Published var todayFocusMinutes: Int = 0
  @Published var todayIdleMinutes: Int = 0
  @Published var todayInterruptions: Int = 0
  @Published var breaksTakenToday: Int = 0
  @Published var breaksSkippedToday: Int = 0
  @Published var focusIntensity: Double = 0
  @Published var breakAdherence: Double = 1

  func refresh(context: ModelContext) {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)

    let sessionDescriptor = FetchDescriptor<FocusSession>()
    let sessions = (try? context.fetch(sessionDescriptor)) ?? []

    let eventDescriptor = FetchDescriptor<WellnessEvent>()
    let wellnessEvents = (try? context.fetch(eventDescriptor)) ?? []

    let breakDescriptor = FetchDescriptor<BreakEvent>()
    let breakEvents = (try? context.fetch(breakDescriptor)) ?? []

    let sessionsToday = sessions.filter { $0.startTime >= today }
    let wellnessToday = wellnessEvents.filter { $0.timestamp >= today }
    let breaksToday = breakEvents.filter { $0.timestamp >= today }

    let totalActiveToday = sessionsToday.reduce(0) { $0 + $1.activeSeconds }
    let totalIdleToday = sessionsToday.reduce(0) { $0 + $1.idleSeconds }
    todayFocusMinutes = Int(totalActiveToday / 60.0)
    todayIdleMinutes = Int(totalIdleToday / 60.0)
    todayInterruptions = sessionsToday.reduce(0) { $0 + $1.interruptions }
    focusIntensity = ratio(totalActiveToday, totalActiveToday + totalIdleToday)

    breaksTakenToday = breaksToday.filter { $0.wasCompleted }.count
    breaksSkippedToday = breaksToday.filter { !$0.wasCompleted }.count
    breakAdherence = ratio(Double(breaksTakenToday), Double(breaksTakenToday + breaksSkippedToday))

    var hourly: [Int: Double] = Dictionary(uniqueKeysWithValues: (0...23).map { ($0, 0) })
    for session in sessionsToday {
      let hour = calendar.component(.hour, from: session.startTime)
      hourly[hour, default: 0] += session.activeSeconds / 60.0
    }
    hourlyFocusToday = hourly.mapValues { min(60, $0) }

    var daily: [DailyFocus] = []
    for idx in (0...6).reversed() {
      let day = calendar.date(byAdding: .day, value: -idx, to: now) ?? now
      let start = calendar.startOfDay(for: day)
      let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

      let sessionsInDay = sessions.filter { $0.startTime >= start && $0.startTime < end }
      let totalMinutes = sessionsInDay.reduce(0.0) { $0 + ($1.activeSeconds / 60.0) }
      daily.append(
        DailyFocus(
          date: start,
          minutes: totalMinutes
        )
      )
    }
    weeklyFocus = daily

    let posture = cadence(
      config: WellnessMetricConfig(
        type: .posture,
        title: "Posture",
        icon: "figure.stand",
        frequencyKey: SettingKey.postureFrequency,
        enabledKey: SettingKey.postureEnabled,
        color: .pink
      ),
      events: wellnessToday,
      focusedSecondsToday: totalActiveToday
    )
    let blink = cadence(
      config: WellnessMetricConfig(
        type: .blink,
        title: "Eye Care",
        icon: "eye.fill",
        frequencyKey: SettingKey.blinkFrequency,
        enabledKey: SettingKey.blinkEnabled,
        color: .blue
      ),
      events: wellnessToday,
      focusedSecondsToday: totalActiveToday
    )
    let water = cadence(
      config: WellnessMetricConfig(
        type: .water,
        title: "Hydration",
        icon: "drop.fill",
        frequencyKey: SettingKey.waterFrequency,
        enabledKey: SettingKey.waterEnabled,
        color: .cyan
      ),
      events: wellnessToday,
      focusedSecondsToday: totalActiveToday
    )
    let affirmation = cadence(
      config: WellnessMetricConfig(
        type: .affirmation,
        title: "Affirmations",
        icon: "bolt.fill",
        frequencyKey: SettingKey.affirmationFrequency,
        enabledKey: SettingKey.affirmationEnabled,
        color: .yellow
      ),
      events: wellnessToday,
      focusedSecondsToday: totalActiveToday
    )
    wellnessCadence = [blink, posture, water, affirmation]

    let enabledCadence = wellnessCadence.filter { $0.targetMinutes > 0 }.map(\.progress)
    let cadenceAvg =
      enabledCadence.isEmpty ? 1.0 : (enabledCadence.reduce(0, +) / Double(enabledCadence.count))

    bioScore = Int(round((focusIntensity * 0.45 + breakAdherence * 0.2 + cadenceAvg * 0.35) * 100))
    summary = summaryLine(cadenceAvg: cadenceAvg)
  }

  private func ratio(_ a: Double, _ b: Double) -> Double {
    guard b > 0 else { return 0 }
    return min(1, max(0, a / b))
  }

  private func cadence(
    config: WellnessMetricConfig,
    events: [WellnessEvent],
    focusedSecondsToday: Double
  ) -> WellnessCadence {
    let defaults = UserDefaults.standard
    let enabled = defaults.bool(forKey: config.enabledKey)
    guard enabled else {
      return WellnessCadence(
        title: config.title,
        icon: config.icon,
        shown: 0,
        targetMinutes: 0,
        status: "Off",
        progress: 1,
        color: config.color
      )
    }

    let frequency = saneFrequency(
      configured: defaults.double(forKey: config.frequencyKey),
      fallback: defaultFrequency(for: config.type)
    )
    let shown = events.filter { $0.type == config.type.rawValue }.count
    let targetMinutes = Int(round(frequency / 60.0))
    let progress: Double
    let status: String
    if focusedSecondsToday < frequency, shown == 0 {
      progress = 1
      status = "Not due yet"
    } else if shown == 0 {
      progress = 0
      status = "No reminders shown"
    } else {
      let observedInterval = focusedSecondsToday / Double(shown)
      progress = min(1, max(0, frequency / observedInterval))
      status = "\(shown) shown today"
    }

    return WellnessCadence(
      title: config.title,
      icon: config.icon,
      shown: shown,
      targetMinutes: targetMinutes,
      status: status,
      progress: progress,
      color: config.color
    )
  }

  private func saneFrequency(configured: Double, fallback: Double) -> Double {
    if configured < 60 { return fallback }
    return configured
  }

  private func defaultFrequency(for type: AppStatus.WellnessType) -> Double {
    switch type {
    case .posture: return 600
    case .blink: return 300
    case .water: return 1200
    case .affirmation: return 3600
    }
  }

  private func summaryLine(cadenceAvg: Double) -> String {
    if todayFocusMinutes == 0 {
      return "No focus recorded today yet."
    }
    if focusIntensity < 0.6 {
      return "High idle share today. Consider shorter focus blocks."
    }
    if cadenceAvg < 0.6 {
      return "Wellness reminders are below cadence for your focus time."
    }
    if breakAdherence < 0.6 {
      return "Break adherence is low today. Skipped breaks are climbing."
    }
    return "Good day so far. Focus and wellness cadence are on track."
  }
}
