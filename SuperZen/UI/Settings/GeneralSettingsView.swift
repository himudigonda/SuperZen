import SuperZenCore
import SwiftUI

struct GeneralSettingsView: View {
  @AppStorage(SettingKey.launchAtLogin) private var launchAtLogin = false
  @AppStorage(SettingKey.menuBarDisplay) private var menuBarDisplay: String = SettingsCatalog.menuBarDisplayDefault
  @AppStorage(SettingKey.timerStyle) private var timerStyle: String = SettingsCatalog.timerStyleDefault
  @AppStorage(SettingKey.focusScheduleEnabled) private var focusScheduleEnabled = false
  @AppStorage(SettingKey.focusScheduleStartMinute) private var focusScheduleStartMinute = SettingsCatalog
    .defaultWorkdayStartMinute
  @AppStorage(SettingKey.focusScheduleEndMinute) private var focusScheduleEndMinute = SettingsCatalog
    .defaultWorkdayEndMinute
  @AppStorage(SettingKey.focusScheduleWeekdays) private var focusScheduleWeekdays: String = SettingsCatalog
    .defaultWeekdaysCSV
  @AppStorage(SettingKey.focusScheduleAutoResume) private var focusScheduleAutoResume = true
  @AppStorage(SettingKey.dayProgressEnabled) private var dayProgressEnabled = false
  @AppStorage(SettingKey.dayProgressStartMinute) private var dayProgressStartMinute = SettingsCatalog
    .defaultWorkdayStartMinute
  @AppStorage(SettingKey.dayProgressEndMinute) private var dayProgressEndMinute = SettingsCatalog
    .defaultWorkdayEndMinute
  @AppStorage(SettingKey.dayProgressBarStyle) private var dayProgressBarStyle: String = SettingsCatalog
    .dayProgressBarStyleDefault
  @AppStorage(SettingKey.dayProgressMetric) private var dayProgressMetric: String = SettingsCatalog
    .dayProgressMetricDefault
  @AppStorage(SettingKey.dayProgressFills) private var dayProgressFills = true
  @AppStorage(SettingKey.dailyFocusGoalMinutes) private var dailyFocusGoalMinutes = SettingsCatalog
    .dailyFocusGoalDefault
  @AppStorage(SettingKey.dailyBreakGoalCount) private var dailyBreakGoalCount = SettingsCatalog.dailyBreakGoalDefault
  @AppStorage(SettingKey.dailyWellnessGoalCount) private var dailyWellnessGoalCount = SettingsCatalog
    .dailyWellnessGoalDefault
  @AppStorage(SettingKey.insightsShowGoalLine) private var insightsShowGoalLine = true
  @AppStorage(SettingKey.insightScoringProfile) private var insightScoringProfile: String = SettingsCatalog
    .scoringProfileDefault
  @AppStorage(SettingKey.insightsForecastEnabled) private var insightsForecastEnabled = true

  private var scheduleIssues: [SettingsIssue] {
    SettingsValidation.issues(in: .standard).filter { $0.section == .general }
  }

  var body: some View {
    SettingsPage {
      CardSection("Startup") {
        LabeledToggle(
          String(localized: "Launch at login", comment: "General settings row title"),
          isOn: $launchAtLogin)
        if let reason = LaunchManager.shared.unavailableReason {
          ValidationNote(reason)
        }
      }
      .onAppear { launchAtLogin = LaunchManager.shared.isEnabled }
      .onChange(of: launchAtLogin) { _, enabled in
        let actual = LaunchManager.shared.setLaunchAtLogin(enabled)
        if actual != enabled { launchAtLogin = actual }
      }

      CardSection("Menu Bar") {
        SettingRow(
          String(localized: "Display status in menu bar", comment: "General settings row title")
        ) {
          MenuPicker(
            String(localized: "Display status in menu bar", comment: "General settings row title"),
            selection: $menuBarDisplay,
            options: SettingsCatalog.menuBarDisplayOptions,
            label: { SettingsCatalog.menuBarDisplayName($0) })
        }
        CardDivider()
        SettingRow(String(localized: "Timer style", comment: "General settings row title")) {
          MenuPicker(
            String(localized: "Timer style", comment: "General settings row title"),
            selection: $timerStyle,
            options: SettingsCatalog.timerStyleOptions,
            label: { $0 })
        }
      }

      CardSection("Automation") {
        LabeledToggle(
          String(localized: "Enable focus schedule", comment: "General settings row title"),
          isOn: $focusScheduleEnabled)
        CardDivider()
        Group {
          SettingRow(String(localized: "Active weekdays", comment: "General settings row title")) {
            WeekdayPicker(csv: $focusScheduleWeekdays)
          }
          CardDivider()
          SettingRow(String(localized: "Active hours", comment: "General settings row title")) {
            TimeRangePicker(
              start: $focusScheduleStartMinute, end: $focusScheduleEndMinute,
              rule: .allowsOvernight)
          }
          CardDivider()
          LabeledToggle(
            String(
              localized: "Auto resume in scheduled hours", comment: "General settings row title"),
            isOn: $focusScheduleAutoResume)
        }
        .disabled(!focusScheduleEnabled)
        ForEach(scheduleIssues, id: \.self) { issue in
          CardDivider()
          ValidationNote(issue.message)
        }
      }

      CardSection("Day Progress") {
        LabeledToggle(
          String(localized: "Show day progress", comment: "General settings row title"),
          isOn: $dayProgressEnabled)
        if dayProgressEnabled {
          CardDivider()
          SettingRow(String(localized: "Day window", comment: "General settings row title")) {
            TimeRangePicker(
              start: $dayProgressStartMinute, end: $dayProgressEndMinute, rule: .allowsOvernight)
          }
          CardDivider()
          SettingRow(
            String(localized: "Style", comment: "General settings row title: day progress style")
          ) {
            MenuPicker(
              String(localized: "Style", comment: "General settings row title: day progress style"),
              selection: $dayProgressBarStyle,
              catalog: SettingsCatalog.dayProgressBarStyles)
          }
          CardDivider()
          SettingRow(
            String(localized: "Metric", comment: "General settings row title: day progress metric")
          ) {
            MenuPicker(
              String(
                localized: "Metric", comment: "General settings row title: day progress metric"),
              selection: $dayProgressMetric,
              catalog: SettingsCatalog.dayProgressMetrics)
          }
          CardDivider()
          SettingRow(
            String(
              localized: "Direction", comment: "General settings row title: day progress direction")
          ) {
            MenuPicker(
              String(
                localized: "Direction",
                comment: "General settings row title: day progress direction"),
              selection: $dayProgressFills,
              catalog: SettingsCatalog.dayProgressFillsOptions)
          }
        }
      }

      CardSection("Goals & Analytics") {
        SettingRow(String(localized: "Daily focus goal", comment: "Goals settings row title")) {
          MenuPicker(
            String(localized: "Daily focus goal", comment: "Goals settings row title"),
            selection: $dailyFocusGoalMinutes,
            options: SettingsCatalog.dailyFocusGoalOptions,
            label: { DurationFormat.compact(Double($0 * 60)) })
        }
        CardDivider()
        SettingRow(String(localized: "Daily break goal", comment: "Goals settings row title")) {
          MenuPicker(
            String(localized: "Daily break goal", comment: "Goals settings row title"),
            selection: $dailyBreakGoalCount,
            options: SettingsCatalog.dailyBreakGoalOptions,
            label: {
              String(localized: "\($0) breaks", comment: "Daily break goal option, plural count")
            })
        }
        CardDivider()
        SettingRow(String(localized: "Daily wellness goal", comment: "Goals settings row title")) {
          MenuPicker(
            String(localized: "Daily wellness goal", comment: "Goals settings row title"),
            selection: $dailyWellnessGoalCount,
            options: SettingsCatalog.dailyWellnessGoalOptions,
            label: {
              String(
                localized: "\($0) reminders", comment: "Daily wellness goal option, plural count")
            })
        }
        CardDivider()
        LabeledToggle(
          String(localized: "Show goal guideline in Insights", comment: "Goals settings row title"),
          isOn: $insightsShowGoalLine)
        CardDivider()
        SettingRow(
          String(localized: "Insight scoring profile", comment: "Goals settings row title"),
          subtitle: String(
            localized: "Choose whether SuperZen prioritizes focus intensity, recovery, or balance",
            comment: "Goals settings row subtitle for insight scoring profile")
        ) {
          MenuPicker(
            String(localized: "Insight scoring profile", comment: "Goals settings row title"),
            selection: $insightScoringProfile,
            options: SettingsCatalog.scoringProfiles,
            label: { SettingsCatalog.scoringProfileDisplayName($0) })
        }
        CardDivider()
        LabeledToggle(
          String(localized: "Enable focus goal forecast", comment: "Goals settings row title"),
          isOn: $insightsForecastEnabled)
      }
    }
  }
}
