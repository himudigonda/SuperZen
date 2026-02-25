import SwiftUI

struct GeneralSettingsView: View {
  @AppStorage(SettingKey.launchAtLogin) var launchAtLogin = true
  @AppStorage("menuBarDisplay") var menuBarDisplay = "Icon and text"
  @AppStorage("timerStyle") var timerStyle = "15:11"

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // SECTION: Startup
      VStack(alignment: .leading, spacing: 10) {
        Text("Startup").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Launch at login") {
            Toggle("", isOn: $launchAtLogin).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }

      // SECTION: Menu Bar
      VStack(alignment: .leading, spacing: 10) {
        Text("Menu Bar").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Display status in menu bar") {
            Menu {
              Button("Icon and text") { menuBarDisplay = "Icon and text" }
              Button("Icon only") { menuBarDisplay = "Icon only" }
            } label: {
              ZenPickerPill(text: menuBarDisplay)
            }.menuStyle(.borderlessButton)
          }

          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Timer style") {
            Menu {
              Button("15:11") { timerStyle = "15:11" }
              Button("15m") { timerStyle = "15m" }
            } label: {
              ZenPickerPill(text: timerStyle)
            }.menuStyle(.borderlessButton)
          }
        }
      }
    }
  }
}
