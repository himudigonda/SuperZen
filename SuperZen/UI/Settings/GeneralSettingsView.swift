import SwiftUI

struct GeneralSettingsView: View {
  @AppStorage(SettingKey.launchAtLogin) var launchAtLogin = false
  @AppStorage(SettingKey.menuBarDisplay) var menuBarDisplay = "Icon and text"
  @AppStorage(SettingKey.timerStyle) var timerStyle = "15:11"

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      // SECTION: Startup
      VStack(alignment: .leading, spacing: 12) {
        Text("Startup")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)

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

      // SECTION: Menu Bar
      VStack(alignment: .leading, spacing: 12) {
        Text("Menu Bar")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)

        ZenCard {
          // Row 1: Display status
          ZenRow(title: "Display status in menu bar") {
            Menu {
              Button("Icon and text") { menuBarDisplay = "Icon and text" }
              Button("Icon only") { menuBarDisplay = "Icon only" }
              Button("Text only") { menuBarDisplay = "Text only" }
            } label: {
              ZenPickerPill(text: menuBarDisplay)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
          }

          Divider().background(Color.white.opacity(0.05))
            .padding(.horizontal, 16)

          // Row 2: Timer style
          ZenRow(title: "Timer style") {
            Menu {
              Button("15:11") { timerStyle = "15:11" }
              Button("15m") { timerStyle = "15m" }
              Button("15") { timerStyle = "15" }
            } label: {
              ZenPickerPill(text: timerStyle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
          }
        }
      }

      Spacer()
    }
  }
}
