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
          ZenRow(title: "Launch at login") {
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
          ZenRow(title: "Display status in menu bar") {
            Menu {
              Button("Icon and text") { menuBarDisplay = "Icon and text" }
              Button("Icon only") { menuBarDisplay = "Icon only" }
              Button("Text only") { menuBarDisplay = "Text only" }
            } label: {
              ZenPickerPill(text: menuBarDisplay)
            }
            .zenMenuStyle()
          }

          ZenRowDivider()

          ZenRow(title: "Timer style") {
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
          ZenRow(title: "Enable focus schedule") {
            Toggle("", isOn: $focusScheduleEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(title: "Active weekdays") {
            ZenWeekdaySelector(weekdaysCSV: $focusScheduleWeekdays)
              .opacity(focusScheduleEnabled ? 1 : 0.45)
              .allowsHitTesting(focusScheduleEnabled)
          }
          ZenRowDivider()
          ZenRow(title: "Active hours") {
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
          ZenRow(title: "Auto resume in scheduled hours") {
            Toggle("", isOn: $focusScheduleAutoResume)
              .toggleStyle(.switch)
              .tint(.blue)
              .opacity(focusScheduleEnabled ? 1 : 0.45)
              .allowsHitTesting(focusScheduleEnabled)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Goals & Analytics")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Daily focus goal") {
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
          ZenRow(title: "Daily break goal") {
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
          ZenRow(title: "Daily wellness goal") {
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
          ZenRow(title: "Show goal guideline in Insights") {
            Toggle("", isOn: $insightsShowGoalLine)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: "Insight scoring profile",
            subtitle: "Choose whether SuperZen prioritizes focus intensity, recovery, or balance"
          ) {
            Menu {
              ForEach(SettingsCatalog.scoringProfiles, id: \.self) { profile in
                Button(profile) { insightScoringProfile = profile }
              }
            } label: {
              ZenPickerPill(text: insightScoringProfile)
            }
            .zenMenuStyle()
          }
          ZenRowDivider()
          ZenRow(title: "Enable focus goal forecast") {
            Toggle("", isOn: $insightsForecastEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
        }
      }

      Spacer()
    }
  }
}

struct AdvancedSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(SettingKey.forceResetFocusAfterBreak) var forceResetFocusAfterBreak = true
  @AppStorage(SettingKey.balancedSkipLockRatio) var balancedSkipLockRatio: Double = 0.5
  @AppStorage(SettingKey.wellnessDurationMultiplier) var wellnessDurationMultiplier: Double = 1.0
  @AppStorage(SettingKey.dataRetentionEnabled) var dataRetentionEnabled = true
  @AppStorage(SettingKey.dataRetentionDays) var dataRetentionDays = 90
  @State private var pruneStatusMessage = "Retention cleanup runs automatically on launch."

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Break enforcement")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: "Reset focus timer after break",
            subtitle: "Disable to resume the interrupted focus block instead of restarting"
          ) {
            Toggle("", isOn: $forceResetFocusAfterBreak)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: "Balanced mode lock window",
            subtitle: "How much of each break must pass before skipping is allowed"
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
        Text("Wellness behavior")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: "Reminder duration scale",
            subtitle: "Adjust how long wellness overlays stay visible"
          ) {
            Menu {
              ForEach(SettingsCatalog.wellnessDurationMultiplierOptions, id: \.1) { option in
                Button(option.0) { wellnessDurationMultiplier = option.1 }
              }
            } label: {
              ZenPickerPill(text: "\(String(format: "%.2g", wellnessDurationMultiplier))x")
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
            title: "Enable retention policy",
            subtitle: "Automatically prune telemetry older than the configured window"
          ) {
            Toggle("", isOn: $dataRetentionEnabled)
              .toggleStyle(.switch)
              .tint(.blue)
          }
          ZenRowDivider()
          ZenRow(title: "Retain telemetry for") {
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
          ZenRow(title: "Run cleanup now") {
            ZenButtonPill(title: "Prune Data") {
              TelemetryService.shared.setup(context: modelContext)
              let summary = TelemetryService.shared.pruneHistoricalData(
                retainingDays: dataRetentionDays)
              pruneStatusMessage =
                "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness)."
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
