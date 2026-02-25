import SwiftUI

// MARK: - Root Settings Container

struct SettingsView: View {
  @State private var selection: String? = "General"

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label("General", systemImage: "gearshape")
          .tag("General")
        Label("Break Schedule", systemImage: "clock")
          .tag("Break Schedule")
        Label("Smart Pause", systemImage: "pause.circle")
          .tag("Smart Pause")
        Label("Appearance", systemImage: "paintpalette")
          .tag("Appearance")
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    } detail: {
      switch selection {
      case "General":
        GeneralSettingsView()
      case "Break Schedule":
        BreakScheduleSettingsView()
      case "Smart Pause":
        SmartPauseSettingsView()
      default:
        Text("Select a category")
          .foregroundColor(.secondary)
      }
    }
    .frame(minWidth: 700, minHeight: 500)
  }
}

// MARK: - General

struct GeneralSettingsView: View {
  @AppStorage(SettingKey.launchAtLogin) var launchAtLogin = true

  var body: some View {
    Form {
      Section("Startup") {
        Toggle("Launch SuperZen at login", isOn: $launchAtLogin)
      }
    }
    .formStyle(.grouped)
    .navigationTitle("General")
  }
}

// MARK: - Break Schedule

struct BreakScheduleSettingsView: View {
  @AppStorage(SettingKey.workDuration) var workMins = 20
  @AppStorage(SettingKey.breakDuration) var breakSecs = 20
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue

  var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  var body: some View {
    Form {
      Section("Durations") {
        Stepper("Work for \(workMins) minutes", value: $workMins, in: 1...60)
        Stepper("Break for \(breakSecs) seconds", value: $breakSecs, in: 10...300, step: 10)
      }

      Section("Enforcement") {
        Picker("Break Difficulty", selection: $difficultyRaw) {
          ForEach(BreakDifficulty.allCases) { diff in
            VStack(alignment: .leading, spacing: 2) {
              Text(diff.rawValue)
              Text(diff.description)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .tag(diff.rawValue)
          }
        }
        .pickerStyle(.radioGroup)

        if difficulty == .hardcore {
          Label("Skipping breaks is disabled. Stay disciplined!", systemImage: "lock.fill")
            .font(.caption)
            .foregroundColor(.orange)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Break Schedule")
  }
}

// MARK: - Smart Pause

struct SmartPauseSettingsView: View {
  @AppStorage(SettingKey.smartPauseMeetings) var pauseMeetings = true
  @AppStorage(SettingKey.smartPauseFullscreen) var pauseFullscreen = true

  var body: some View {
    Form {
      Section("Automatically pause during") {
        Toggle("Meetings or Calls", isOn: $pauseMeetings)
        Toggle("Fullscreen Apps (Games / Movies)", isOn: $pauseFullscreen)
      }
      Section {
        Label(
          "SuperZen will resume automatically once the context clears.",
          systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Smart Pause")
  }
}
