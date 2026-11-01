import SwiftUI

struct GeneralSettingsView: View {
  @State private var launchAtLogin = false
  @State private var menuBarDisplay: String = SettingsCatalog.menuBarDisplayDefault
  @State private var timerStyle: String = SettingsCatalog.timerStyleDefault
  @State private var focusScheduleEnabled = false
  @State private var focusScheduleStartMinute = SettingsCatalog.defaultWorkdayStartMinute
  @State private var focusScheduleEndMinute = SettingsCatalog.defaultWorkdayEndMinute
  @State private var focusScheduleWeekdays: String = SettingsCatalog.defaultWeekdaysCSV
  @State private var focusScheduleAutoResume = true
  @State private var dayProgressEnabled = false
  @State private var dayProgressStartMinute = SettingsCatalog.defaultWorkdayStartMinute
  @State private var dayProgressEndMinute = SettingsCatalog.defaultWorkdayEndMinute
  @State private var dayProgressBarStyle: String = SettingsCatalog.dayProgressBarStyleDefault
  @State private var dayProgressMetric: String = SettingsCatalog.dayProgressMetricDefault
  @State private var dayProgressFills = true
  @State private var dailyFocusGoalMinutes = SettingsCatalog.dailyFocusGoalDefault
  @State private var dailyBreakGoalCount = SettingsCatalog.dailyBreakGoalDefault
  @State private var dailyWellnessGoalCount = SettingsCatalog.dailyWellnessGoalDefault
  @State private var insightsShowGoalLine = true
  @State private var insightScoringProfile: String = SettingsCatalog.scoringProfileDefault
  @State private var insightsForecastEnabled = true

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
              ForEach(SettingsCatalog.menuBarDisplayOptions, id: \.self) { option in
                Button(SettingsCatalog.menuBarDisplayName(option)) { menuBarDisplay = option }
              }
            } label: {
              ZenPickerPill(text: SettingsCatalog.menuBarDisplayName(menuBarDisplay))
            }
            .zenMenuStyle()
          }

          ZenRowDivider()

          ZenRow(title: String(localized: "Timer style", comment: "General settings row title")) {
            Menu {
              ForEach(SettingsCatalog.timerStyleOptions, id: \.self) { option in
                Button(option) { timerStyle = option }
              }
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
              ForEach(SettingsCatalog.dailyFocusGoalOptions, id: \.self) { minutes in
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
              ForEach(SettingsCatalog.dailyBreakGoalOptions, id: \.self) { count in
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
              ForEach(SettingsCatalog.dailyWellnessGoalOptions, id: \.self) { count in
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

      SettingsSaveBar(onSave: save)
      Spacer()
    }
    .task { load() }
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

  private func load() {
    let d = UserDefaults.standard
    launchAtLogin = d.bool(forKey: SettingKey.launchAtLogin)
    menuBarDisplay =
      d.string(forKey: SettingKey.menuBarDisplay) ?? SettingsCatalog.menuBarDisplayDefault
    timerStyle = d.string(forKey: SettingKey.timerStyle) ?? SettingsCatalog.timerStyleDefault
    focusScheduleEnabled = d.bool(forKey: SettingKey.focusScheduleEnabled)
    focusScheduleStartMinute = d.integer(forKey: SettingKey.focusScheduleStartMinute)
    focusScheduleEndMinute = d.integer(forKey: SettingKey.focusScheduleEndMinute)
    focusScheduleWeekdays =
      d.string(forKey: SettingKey.focusScheduleWeekdays) ?? SettingsCatalog.defaultWeekdaysCSV
    focusScheduleAutoResume = d.bool(forKey: SettingKey.focusScheduleAutoResume)
    dayProgressEnabled = d.bool(forKey: SettingKey.dayProgressEnabled)
    dayProgressStartMinute = d.integer(forKey: SettingKey.dayProgressStartMinute)
    dayProgressEndMinute = d.integer(forKey: SettingKey.dayProgressEndMinute)
    dayProgressBarStyle =
      d.string(forKey: SettingKey.dayProgressBarStyle) ?? SettingsCatalog.dayProgressBarStyleDefault
    dayProgressMetric =
      d.string(forKey: SettingKey.dayProgressMetric) ?? SettingsCatalog.dayProgressMetricDefault
    dayProgressFills = d.bool(forKey: SettingKey.dayProgressFills)
    dailyFocusGoalMinutes = d.integer(forKey: SettingKey.dailyFocusGoalMinutes)
    dailyBreakGoalCount = d.integer(forKey: SettingKey.dailyBreakGoalCount)
    dailyWellnessGoalCount = d.integer(forKey: SettingKey.dailyWellnessGoalCount)
    insightsShowGoalLine = d.bool(forKey: SettingKey.insightsShowGoalLine)
    insightScoringProfile =
      d.string(forKey: SettingKey.insightScoringProfile) ?? SettingsCatalog.scoringProfileDefault
    insightsForecastEnabled = d.bool(forKey: SettingKey.insightsForecastEnabled)
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(launchAtLogin, forKey: SettingKey.launchAtLogin)
    d.set(menuBarDisplay, forKey: SettingKey.menuBarDisplay)
    d.set(timerStyle, forKey: SettingKey.timerStyle)
    d.set(focusScheduleEnabled, forKey: SettingKey.focusScheduleEnabled)
    d.set(focusScheduleStartMinute, forKey: SettingKey.focusScheduleStartMinute)
    d.set(focusScheduleEndMinute, forKey: SettingKey.focusScheduleEndMinute)
    d.set(focusScheduleWeekdays, forKey: SettingKey.focusScheduleWeekdays)
    d.set(focusScheduleAutoResume, forKey: SettingKey.focusScheduleAutoResume)
    d.set(dayProgressEnabled, forKey: SettingKey.dayProgressEnabled)
    d.set(dayProgressStartMinute, forKey: SettingKey.dayProgressStartMinute)
    d.set(dayProgressEndMinute, forKey: SettingKey.dayProgressEndMinute)
    d.set(dayProgressBarStyle, forKey: SettingKey.dayProgressBarStyle)
    d.set(dayProgressMetric, forKey: SettingKey.dayProgressMetric)
    d.set(dayProgressFills, forKey: SettingKey.dayProgressFills)
    d.set(dailyFocusGoalMinutes, forKey: SettingKey.dailyFocusGoalMinutes)
    d.set(dailyBreakGoalCount, forKey: SettingKey.dailyBreakGoalCount)
    d.set(dailyWellnessGoalCount, forKey: SettingKey.dailyWellnessGoalCount)
    d.set(insightsShowGoalLine, forKey: SettingKey.insightsShowGoalLine)
    d.set(insightScoringProfile, forKey: SettingKey.insightScoringProfile)
    d.set(insightsForecastEnabled, forKey: SettingKey.insightsForecastEnabled)

    // LaunchManager/SMAppService registration is a real side effect (not just a UserDefaults
    // write), so it only fires once the user actually commits the change via Save.
    LaunchManager.shared.setLaunchAtLogin(launchAtLogin)
  }
}

struct AdvancedSettingsView: View {
  @State private var balancedSkipLockRatio: Double = SettingsCatalog.balancedSkipLockRatioDefault
  @State private var dataRetentionEnabled = true
  @State private var dataRetentionDays = SettingsCatalog.dataRetentionDaysDefault
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

      SettingsSaveBar(onSave: save)
      Spacer()
    }
    .task { load() }
  }

  private var skipLockLabel: String {
    let percentage = Int((balancedSkipLockRatio * 100).rounded())
    return "\(percentage)% of break"
  }

  private func load() {
    let d = UserDefaults.standard
    balancedSkipLockRatio = d.double(forKey: SettingKey.balancedSkipLockRatio)
    dataRetentionEnabled = d.bool(forKey: SettingKey.dataRetentionEnabled)
    dataRetentionDays = d.integer(forKey: SettingKey.dataRetentionDays)
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(balancedSkipLockRatio, forKey: SettingKey.balancedSkipLockRatio)
    d.set(dataRetentionEnabled, forKey: SettingKey.dataRetentionEnabled)
    d.set(dataRetentionDays, forKey: SettingKey.dataRetentionDays)
  }
}
