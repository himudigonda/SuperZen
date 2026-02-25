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
          Button(
            action: {},
            label: {
              Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            }
          )
          .buttonStyle(.plain)

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
                LookAwayBreakScheduleView()
              case "Smart Pause":
                SmartPauseView()
              case "Insights":
                DashboardView()
              default:
                Text("Work in progress...")
                  .font(.system(size: 14))
                  .foregroundColor(Theme.textSecondary)
                  .padding(.top, 40)
              }
            }
            .padding(32)
            // This prevents the scrollview from clipping the bottom of the last card
            .padding(.bottom, 40)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Theme.backgroundColor)
      .ignoresSafeArea(.all, edges: .top)
    }
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
