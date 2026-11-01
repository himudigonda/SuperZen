import SwiftData
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
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      CardSection("Startup") {
        LabeledToggle(
          String(localized: "Launch at login", comment: "General settings row title"),
          isOn: $launchAtLogin)
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
      }

      CardSection("Day Progress") {
        LabeledToggle(
          String(localized: "Show day progress", comment: "General settings row title"),
          isOn: $dayProgressEnabled)
        if dayProgressEnabled {
          CardDivider()
          SettingRow(String(localized: "Day window", comment: "General settings row title")) {
            TimeRangePicker(
              start: $dayProgressStartMinute, end: $dayProgressEndMinute, rule: .sameDay)
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

      SettingsSaveBar(onSave: save)
      Spacer()
    }
    .task { load() }
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

    LaunchManager.shared.setLaunchAtLogin(launchAtLogin)
  }
}

struct AdvancedSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var balancedSkipLockRatio: Double = SettingsCatalog.balancedSkipLockRatioDefault
  @State private var dataRetentionEnabled = true
  @State private var dataRetentionDays = SettingsCatalog.dataRetentionDaysDefault
  @State private var pruneStatusMessage = String(
    localized: "Retention cleanup runs automatically on launch.",
    comment: "Advanced settings: default status message before a manual prune has run")

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      CardSection("Break enforcement") {
        SettingRow(
          String(localized: "Balanced mode lock window", comment: "Advanced settings row title"),
          subtitle: String(
            localized: "How much of each break must pass before skipping is allowed",
            comment: "Advanced settings row subtitle for balanced mode lock window")
        ) {
          MenuPicker(
            String(localized: "Balanced mode lock window", comment: "Advanced settings row title"),
            selection: $balancedSkipLockRatio,
            catalog: SettingsCatalog.balancedSkipLockOptions)
        }
      }

      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        CardSection("Analytics retention") {
          LabeledToggle(
            String(localized: "Enable retention policy", comment: "Advanced settings row title"),
            subtitle: String(
              localized: "Automatically prune telemetry older than the configured window",
              comment: "Advanced settings row subtitle for retention policy"),
            isOn: $dataRetentionEnabled)
          CardDivider()
          Group {
            SettingRow(
              String(localized: "Retain telemetry for", comment: "Advanced settings row title")
            ) {
              MenuPicker(
                String(localized: "Retain telemetry for", comment: "Advanced settings row title"),
                selection: $dataRetentionDays,
                options: SettingsCatalog.retentionDaysOptions,
                label: {
                  String(localized: "\($0) days", comment: "Retention window option, plural count")
                })
            }
            CardDivider()
            SettingRow(String(localized: "Run cleanup now", comment: "Advanced settings row title")) {
              PillButton(String(localized: "Prune Data", comment: "Advanced settings button")) {
                prune()
              }
            }
          }
          .disabled(!dataRetentionEnabled)
        }

        Text(pruneStatusMessage)
          .font(ZenFont.subheadline)
          .foregroundStyle(ZenColor.textSecondary)
      }

      SettingsSaveBar(onSave: save)
      Spacer()
    }
    .task { load() }
  }

  private func prune() {
    TelemetryService.shared.setup(context: modelContext)
    let summary = TelemetryService.shared.pruneHistoricalData(retainingDays: dataRetentionDays)
    pruneStatusMessage = String(
      localized:
        "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app-usage rows).",
      comment: "Status message after pruning telemetry, with per-category counts")
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
