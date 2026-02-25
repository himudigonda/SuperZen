import SwiftUI

struct SmartPauseView: View {
  @EnvironmentObject var stateManager: StateManager

  @AppStorage(SettingKey.smartPauseMeetings) var pauseMeetings = true
  @AppStorage("pauseVideo") var pauseVideo = false
  @AppStorage("pauseCalendar") var pauseCalendar = false
  @AppStorage("pauseDeepFocus") var pauseDeepFocus = false
  @AppStorage(SettingKey.smartPauseFullscreen) var pauseGaming = false

  @AppStorage("askDidYouTakeBreak") var askDidYouTakeBreak = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // SECTION: Automatically pause
      VStack(alignment: .leading, spacing: 10) {
        Text("Automatically pause SuperZen during").font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenFeatureRow(
            icon: "headphones", title: "Meetings or Calls",
            subtitle: "Pauses breaks during calls and online meetings"
          ) {
            HStack(spacing: 12) {
              ZenButtonPill(title: "Options...") {}
              Toggle("", isOn: $pauseMeetings).toggleStyle(.switch).tint(Theme.accent)
            }
          }
          Divider().background(Color.white.opacity(0.05))

          ZenFeatureRow(
            icon: "video.fill", title: "Video playback",
            subtitle: "Pauses breaks while any video is playing"
          ) {
            HStack(spacing: 12) {
              ZenButtonPill(title: "Options...") {}
              Toggle("", isOn: $pauseVideo).toggleStyle(.switch).tint(Theme.accent)
            }
          }
          Divider().background(Color.white.opacity(0.05))

          ZenFeatureRow(
            icon: "calendar", title: "Calendar Events",
            subtitle: "Pauses breaks when a calendar event is ongoing"
          ) {
            HStack(spacing: 12) {
              ZenButtonPill(title: "Continue...") {}
              Toggle("", isOn: $pauseCalendar).toggleStyle(.switch).tint(Theme.accent)
            }
          }
          Divider().background(Color.white.opacity(0.05))

          ZenFeatureRow(
            icon: "macwindow.badge.plus", title: "Deep focus apps",
            subtitle: "Pauses breaks when your chosen apps are active"
          ) {
            HStack(spacing: 12) {
              ZenButtonPill(title: "Options...") {}
              Toggle("", isOn: $pauseDeepFocus).toggleStyle(.switch).tint(Theme.accent)
            }
          }
          Divider().background(Color.white.opacity(0.05))

          ZenFeatureRow(
            icon: "gamecontroller.fill", title: "Gaming",
            subtitle: "Pauses breaks while you play fullscreen games"
          ) {
            HStack(spacing: 12) {
              ZenButtonPill(title: "Options...") {}
              Toggle("", isOn: $pauseGaming).toggleStyle(.switch).tint(Theme.accent)
            }
          }
          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Cooldown after smart pause ends") {
            ZenPickerPill(text: "1 minute")
          }
        }
      }

      // SECTION: Idle Tracking
      VStack(alignment: .leading, spacing: 10) {
        Text("Idle Tracking").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)

        ZenCard {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Pause or resume SuperZen when I step away")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary)
              Spacer()
              ZenPickerPill(text: "Automatic")
            }
            Text(
              "SuperZen will pause or reset timers based on your activity and settings. "
                + "If unsure, it will ask for your input based on the setting below."
            )
            .font(.system(size: 11))
            .foregroundColor(Theme.textSecondary)
            .lineSpacing(2)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)

          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Ask \"Did you take a break?\" on returning from idle") {
            Toggle("", isOn: $askDidYouTakeBreak).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }
    }
  }
}
