import SwiftUI

struct ContentView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    DashboardView()
      .frame(minWidth: 650, minHeight: 450)
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
