import SwiftUI

struct ContentView: View {
  @State private var selection: PreferencesSection? = .general

  var body: some View {
    NavigationSplitView {
      CustomSidebar(selection: $selection)
        .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 280)
    } detail: {
      detailView(for: selection ?? .general)
        .navigationTitle((selection ?? .general).title)
    }
    .background(ZenCanvasBackground())
    .frame(minWidth: 850, idealWidth: 900, minHeight: 600, idealHeight: 650)
    .onAppear {
      if let window = NSApp.windows.first(where: { $0.title == "SuperZen" }) {
        window.center()
      }
    }
  }

  @ViewBuilder
  private func detailView(for section: PreferencesSection) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        switch section {
        case .general:
          GeneralSettingsView()
        case .breakSchedule:
          SuperZenBreakScheduleView()
        case .wellnessReminders:
          WellnessRemindersView()
        case .appearance:
          AppearanceView()
        case .soundEffects:
          SoundEffectsView()
        case .keyboardShortcuts:
          KeyboardShortcutsView()
        case .advanced:
          AdvancedSettingsView()
        case .about:
          AboutView()
        case .insights:
          DashboardView()
        }
      }
      .padding(32)
      .padding(.bottom, 40)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background {
      ZenCanvasBackground()
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
