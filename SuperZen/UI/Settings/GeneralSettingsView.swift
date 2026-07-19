import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
  @AppStorage(SettingKey.launchAtLogin) var launchAtLogin = false
  @AppStorage(SettingKey.menuBarDisplay) var menuBarDisplay = "Icon and text"
  @AppStorage(SettingKey.timerStyle) var timerStyle = "15:11"
  @AppStorage(SettingKey.focusScheduleEnabled) var focusScheduleEnabled = false
  @AppStorage(SettingKey.focusScheduleStartMinute) var focusScheduleStartMinute = 540
  @AppStorage(SettingKey.focusScheduleEndMinute) var focusScheduleEndMinute = 1080
  @AppStorage(SettingKey.focusScheduleWeekdays) var focusScheduleWeekdays = "2,3,4,5,6"
  @AppStorage(SettingKey.focusScheduleAutoResume) var focusScheduleAutoResume = true
  @AppStorage(SettingKey.dayProgressEnabled) var dayProgressEnabled = false
  @AppStorage(SettingKey.dayProgressStartMinute) var dayProgressStartMinute = 540
  @AppStorage(SettingKey.dayProgressEndMinute) var dayProgressEndMinute = 1080
  @AppStorage(SettingKey.dayProgressBarStyle) var dayProgressBarStyle = "bar_label"
  @AppStorage(SettingKey.dayProgressMetric) var dayProgressMetric = "pct_done"
  @AppStorage(SettingKey.dayProgressFills) var dayProgressFills = true
  @AppStorage(SettingKey.dailyFocusGoalMinutes) var dailyFocusGoalMinutes = 240
  @AppStorage(SettingKey.dailyBreakGoalCount) var dailyBreakGoalCount = 6
  @AppStorage(SettingKey.dailyWellnessGoalCount) var dailyWellnessGoalCount = 8
  @AppStorage(SettingKey.insightsShowGoalLine) var insightsShowGoalLine = true
  @AppStorage(SettingKey.insightScoringProfile) var insightScoringProfile = "Balanced"
  @AppStorage(SettingKey.insightsForecastEnabled) var insightsForecastEnabled = true

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Startup")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: String(localized: "Launch at login", comment: "General settings row title")) {
            Toggle("", isOn: $launchAtLogin)
              .toggleStyle(.switch)
              .tint(.blue)
              .onChange(of: launchAtLogin) { _, newValue in
                LaunchManager.shared.setLaunchAtLogin(newValue)
              }
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Menu Bar")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(
              localized: "Display status in menu bar", comment: "General settings row title")
          ) {
            Menu {
              Button("Icon and text") { menuBarDisplay = "Icon and text" }
              Button("Icon only") { menuBarDisplay = "Icon only" }
              Button("Text only") { menuBarDisplay = "Text only" }
            } label: {
              ZenPickerPill(text: SettingsCatalog.menuBarDisplayName(menuBarDisplay))
            }
            .zenMenuStyle()
          }

          ZenRowDivider()

          ZenRow(title: String(localized: "Timer style", comment: "General settings row title")) {
            Menu {
              Button("15:11") { timerStyle = "15:11" }
              Button("15m") { timerStyle = "15m" }
              Button("15") { timerStyle = "15" }
            } label: {
              ZenPickerPill(text: timerStyle)
            }
            .zenMenuStyle()
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Automation")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(localized: "Enable focus schedule", comment: "General settings row title")
          ) {
            Toggle("", isOn: $focusScheduleEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(title: String(localized: "Active weekdays", comment: "General settings row title")) {
            ZenWeekdaySelector(weekdaysCSV: $focusScheduleWeekdays)
              .opacity(focusScheduleEnabled ? 1 : 0.45)
              .allowsHitTesting(focusScheduleEnabled)
          }
          ZenRowDivider()
          ZenRow(title: String(localized: "Active hours", comment: "General settings row title")) {
            HStack(spacing: 8) {
              ZenTimePicker(minuteOfDay: $focusScheduleStartMinute)
              Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
              ZenTimePicker(minuteOfDay: $focusScheduleEndMinute)
            }
            .opacity(focusScheduleEnabled ? 1 : 0.45)
            .allowsHitTesting(focusScheduleEnabled)
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Auto resume in scheduled hours", comment: "General settings row title")
          ) {
            Toggle("", isOn: $focusScheduleAutoResume)
              .toggleStyle(.switch)
              .tint(.blue)
              .opacity(focusScheduleEnabled ? 1 : 0.45)
              .allowsHitTesting(focusScheduleEnabled)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Day Progress")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(localized: "Show day progress", comment: "General settings row title")
          ) {
            Toggle("", isOn: $dayProgressEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          if dayProgressEnabled {
            ZenRowDivider()
            ZenRow(title: String(localized: "Start of day", comment: "General settings row title")) {
              ZenTimePicker(minuteOfDay: $dayProgressStartMinute)
            }
            ZenRowDivider()
            ZenRow(title: String(localized: "End of day", comment: "General settings row title")) {
              ZenTimePicker(minuteOfDay: $dayProgressEndMinute)
            }
            ZenRowDivider()
            ZenRow(
              title: String(
                localized: "Style", comment: "General settings row title: day progress style")
            ) {
              Menu {
                ForEach(SettingsCatalog.dayProgressBarStyles, id: \.1) { option in
                  Button(option.0) { dayProgressBarStyle = option.1 }
                }
              } label: {
                ZenPickerPill(text: styleLabel)
              }
              .zenMenuStyle()
            }
            ZenRowDivider()
            ZenRow(
              title: String(
                localized: "Metric", comment: "General settings row title: day progress metric")
            ) {
              Menu {
                ForEach(SettingsCatalog.dayProgressMetrics, id: \.1) { option in
                  Button(option.0) { dayProgressMetric = option.1 }
                }
              } label: {
                ZenPickerPill(text: metricLabel)
              }
              .zenMenuStyle()
            }
            ZenRowDivider()
            ZenRow(
              title: String(
                localized: "Direction",
                comment: "General settings row title: day progress direction")
            ) {
              Menu {
                ForEach(SettingsCatalog.dayProgressFillsOptions, id: \.1) { option in
                  Button(option.0) { dayProgressFills = option.1 }
                }
              } label: {
                ZenPickerPill(text: directionLabel)
              }
              .zenMenuStyle()
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Goals & Analytics")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: String(localized: "Daily focus goal", comment: "Goals settings row title")) {
            Menu {
              ForEach([90, 120, 180, 240, 300, 360], id: \.self) { minutes in
                Button("\(minutes)m") { dailyFocusGoalMinutes = minutes }
              }
            } label: {
              ZenPickerPill(text: "\(dailyFocusGoalMinutes)m")
            }
            .zenMenuStyle()
          }
          ZenRowDivider()
          ZenRow(title: String(localized: "Daily break goal", comment: "Goals settings row title")) {
            Menu {
              ForEach([2, 4, 6, 8, 10, 12], id: \.self) { count in
                Button("\(count) breaks") { dailyBreakGoalCount = count }
              }
            } label: {
              ZenPickerPill(text: "\(dailyBreakGoalCount) breaks")
            }
            .zenMenuStyle()
          }
          ZenRowDivider()
          ZenRow(
            title: String(localized: "Daily wellness goal", comment: "Goals settings row title")
          ) {
            Menu {
              ForEach([2, 4, 6, 8, 10, 12], id: \.self) { count in
                Button("\(count) reminders") { dailyWellnessGoalCount = count }
              }
            } label: {
              ZenPickerPill(text: "\(dailyWellnessGoalCount) reminders")
            }
            .zenMenuStyle()
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Show goal guideline in Insights", comment: "Goals settings row title")
          ) {
            Toggle("", isOn: $insightsShowGoalLine)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Insight scoring profile", comment: "Goals settings row title"),
            subtitle: String(
              localized:
                "Choose whether SuperZen prioritizes focus intensity, recovery, or balance",
              comment: "Goals settings row subtitle for insight scoring profile")
          ) {
            Menu {
              ForEach(SettingsCatalog.scoringProfiles, id: \.self) { profile in
                Button(SettingsCatalog.scoringProfileDisplayName(profile)) {
                  insightScoringProfile = profile
                }
              }
            } label: {
              ZenPickerPill(text: SettingsCatalog.scoringProfileDisplayName(insightScoringProfile))
            }
            .zenMenuStyle()
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Enable focus goal forecast", comment: "Goals settings row title")
          ) {
            Toggle("", isOn: $insightsForecastEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
        }
      }

      Spacer()
    }
  }

  private var styleLabel: String {
    SettingsCatalog.dayProgressBarStyles.first { $0.1 == dayProgressBarStyle }?.0 ?? "Bar + Label"
  }

  private var metricLabel: String {
    SettingsCatalog.dayProgressMetrics.first { $0.1 == dayProgressMetric }?.0 ?? "% done"
  }

  private var directionLabel: String {
    SettingsCatalog.dayProgressFillsOptions.first { $0.1 == dayProgressFills }?.0 ?? "Fills →"
  }
}

struct AdvancedSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(SettingKey.balancedSkipLockRatio) var balancedSkipLockRatio: Double = 0.5
  @AppStorage(SettingKey.dataRetentionEnabled) var dataRetentionEnabled = true
  @AppStorage(SettingKey.dataRetentionDays) var dataRetentionDays = 90
  @State private var pruneStatusMessage = String(
    localized: "Retention cleanup runs automatically on launch.",
    comment: "Advanced settings: default status message before a manual prune has run")

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Break enforcement")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(
              localized: "Balanced mode lock window", comment: "Advanced settings row title"),
            subtitle: String(
              localized: "How much of each break must pass before skipping is allowed",
              comment: "Advanced settings row subtitle for balanced mode lock window")
          ) {
            Menu {
              ForEach(SettingsCatalog.balancedSkipLockOptions, id: \.1) { option in
                Button(option.0) { balancedSkipLockRatio = option.1 }
              }
            } label: {
              ZenPickerPill(text: skipLockLabel)
            }
            .zenMenuStyle()
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Analytics retention")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(
              localized: "Enable retention policy", comment: "Advanced settings row title"),
            subtitle: String(
              localized: "Automatically prune telemetry older than the configured window",
              comment: "Advanced settings row subtitle for retention policy")
          ) {
            Toggle("", isOn: $dataRetentionEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: String(localized: "Retain telemetry for", comment: "Advanced settings row title")
          ) {
            Menu {
              ForEach(SettingsCatalog.retentionDaysOptions, id: \.self) { days in
                Button("\(days) days") { dataRetentionDays = days }
              }
            } label: {
              ZenPickerPill(text: "\(dataRetentionDays) days")
            }
            .zenMenuStyle()
            .opacity(dataRetentionEnabled ? 1 : 0.45)
            .allowsHitTesting(dataRetentionEnabled)
          }
          ZenRowDivider()
          ZenRow(
            title: String(localized: "Run cleanup now", comment: "Advanced settings row title")
          ) {
            ZenButtonPill(
              title: String(localized: "Prune Data", comment: "Advanced settings button")
            ) {
              TelemetryService.shared.setup(context: modelContext)
              let summary = TelemetryService.shared.pruneHistoricalData(
                retainingDays: dataRetentionDays)
              pruneStatusMessage = String(
                localized:
                  "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app-usage rows).",
                comment: "Status message after pruning telemetry, with per-category counts")
            }
            .disabled(!dataRetentionEnabled)
          }
        }

        Text(pruneStatusMessage)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Theme.textSecondary)
      }

      Spacer()
    }
  }

  private var skipLockLabel: String {
    let percentage = Int((balancedSkipLockRatio * 100).rounded())
    return "\(percentage)% of break"
  }
}
