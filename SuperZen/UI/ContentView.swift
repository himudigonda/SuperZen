import SwiftUI

struct ContentView: View {
  // Default tab when the app opens
  @State private var selection: String = "Insights"
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: 0) {
      // Left Sidebar
      CustomSidebar(selection: $selection)
        .ignoresSafeArea(.all, edges: .top)  // Push behind traffic lights

      // Subtle 1px divider
      Rectangle()
        .fill(Color.black.opacity(0.6))
        .frame(width: 1)

      // Right Pane Content
      VStack(alignment: .leading, spacing: 0) {
        // Custom Header (matching LookAway)
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
        .padding(.top, 24)  // Align with traffic lights
        .padding(.bottom, 16)

        Divider().background(Color.white.opacity(0.05))

        // Dynamic Content Area
        ZStack {
          Theme.backgroundColor.ignoresSafeArea()

          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              switch selection {
              case "Insights":
                DashboardView()
              case "Break Schedule":
                LookAwayBreakScheduleView()
              default:
                Text("Work in progress...")
                  .font(.system(size: 14))
                  .foregroundColor(Theme.textSecondary)
                  .padding(.top, 40)
              }
            }
            .padding(32)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Theme.backgroundColor)
      .ignoresSafeArea(.all, edges: .top)
    }
    .frame(width: 900, height: 650)  // LookAway dimensions
    .preferredColorScheme(.dark)  // Force dark mode globally
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
