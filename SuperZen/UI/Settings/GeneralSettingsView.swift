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
              .onChange(of: launchAtLogin) { newValue in
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
        }
      }

      Spacer()
    }
  }
}
