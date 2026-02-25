import SwiftUI

struct ContentView: View {
  @State private var selection: String = "General"
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: 0) {
      CustomSidebar(selection: $selection)
        .ignoresSafeArea(.all, edges: .top)

      Rectangle()
        .fill(Color.black.opacity(0.6))
        .frame(width: 1)

      VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack(spacing: 12) {
          Text(selection)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Theme.textPrimary)

          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)

        Divider().background(Color.white.opacity(0.05))

        // Dynamic Content Router
        ZStack {
          Theme.backgroundColor.ignoresSafeArea()

          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              switch selection {
              case "General":
                GeneralSettingsView()
              case "Break Schedule":
                SuperZenBreakScheduleView()
              case "Wellness Reminders":
                WellnessRemindersView()
              case "Appearance":
                AppearanceView()
              case "Sound Effects":
                SoundEffectsView()
              case "Keyboard Shortcuts":
                KeyboardShortcutsView()
              case "About":
                AboutView()
              case "Insights":
                DashboardView()
              default:
                EmptyView()
              }
            }
            .padding(32)
            .padding(.bottom, 40)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Theme.backgroundColor)
      .ignoresSafeArea(.all, edges: .top)
    }
    .frame(minWidth: 850, idealWidth: 900, minHeight: 600, idealHeight: 650)
    .preferredColorScheme(.dark)
    .onAppear {
      if let window = NSApp.windows.first(where: { $0.title == "SuperZen" }) {
        window.center()
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
