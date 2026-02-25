import SwiftUI

struct SmartPauseView: View {
  @EnvironmentObject var stateManager: StateManager

  @AppStorage(SettingKey.pauseMeetings) var pauseMeetings = true
  @AppStorage(SettingKey.pauseVideo) var pauseVideo = false
  @AppStorage(SettingKey.pauseCalendar) var pauseCalendar = false
  @AppStorage(SettingKey.pauseFocusApps) var pauseFocusApps = false
  @AppStorage(SettingKey.pauseGaming) var pauseGaming = false
  @AppStorage(SettingKey.cooldownMinutes) var cooldownMinutes = 1
  @AppStorage(SettingKey.askDidYouTakeBreak) var askDidYouTakeBreak = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      VStack(alignment: .leading, spacing: 12) {
        Text("Automatically pause SuperZen during").font(.system(size: 13, weight: .bold))

        ZenCard {
          SmartPauseRow(
            icon: "headphones", title: "Meetings or Calls",
            subtitle: "Pauses breaks during calls and online meetings", isOn: $pauseMeetings,
            btn: "Options...")

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          SmartPauseRow(
            icon: "video.fill", title: "Video playback",
            subtitle: "Pauses breaks while any video is playing", isOn: $pauseVideo,
            btn: "Options...")

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          SmartPauseRow(
            icon: "calendar", title: "Calendar Events",
            subtitle: "Pauses breaks when a calendar event is ongoing", isOn: $pauseCalendar,
            btn: "Continue...")

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          SmartPauseRow(
            icon: "macwindow.badge.plus", title: "Deep focus apps",
            subtitle: "Pauses breaks when your chosen apps are active", isOn: $pauseFocusApps,
            btn: "Options...")

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          SmartPauseRow(
            icon: "gamecontroller.fill", title: "Gaming",
            subtitle: "Pauses breaks while you play fullscreen games", isOn: $pauseGaming,
            btn: "Options...")

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Cooldown after smart pause ends") {
            Menu {
              ForEach([1, 2, 5], id: \.self) { m in Button("\(m) minute") { cooldownMinutes = m } }
            } label: {
              ZenPickerPill(text: "\(cooldownMinutes) minute")
            }.menuStyle(.borderlessButton).fixedSize()
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Idle Tracking").font(.system(size: 13, weight: .bold))
        ZenCard {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Pause or resume SuperZen when I step away").font(
                .system(size: 13, weight: .medium))
              Spacer()
              ZenPickerPill(text: "Automatic")
            }
            Text(
              "SuperZen will pause or reset timers based on your activity and settings. If unsure, it will ask for your input based on the setting below."
            )
            .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
          }
          .padding(16)

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Ask \"Did you take a break?\" on returning from idle") {
            Toggle("", isOn: $askDidYouTakeBreak).toggleStyle(.switch).tint(.blue)
          }
        }
      }
    }
  }
}

struct SmartPauseRow: View {
  let icon: String
  let title: String
  let subtitle: String
  @Binding var isOn: Bool
  let btn: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon).font(.system(size: 18)).foregroundColor(Theme.textSecondary).frame(
        width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 13, weight: .medium))
        Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
      }
      Spacer()
      HStack(spacing: 12) {
        ZenButtonPill(title: btn) {}
        Toggle("", isOn: $isOn).toggleStyle(.switch).tint(.blue)
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 12)
  }
}
