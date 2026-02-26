import SwiftUI

struct ContentView: View {
  let stateManager: StateManager
  @SceneStorage("superzen.preferences.selection")
  private var selectionRawValue: String = PreferencesSection.general.rawValue

  var body: some View {
    let selection = resolvedSelection
    NavigationSplitView {
      CustomSidebar(selection: selectionBinding)
        .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 280)
    } detail: {
      detailView(for: selection)
        .navigationTitle(selection.title)
    }
    .background(ZenCanvasBackground())
    .frame(minWidth: 850, idealWidth: 900, minHeight: 600, idealHeight: 650)
    .animation(.snappy(duration: 0.2, extraBounce: 0), value: selectionRawValue)
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
          AppearanceView(stateManager: stateManager)
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

  private var resolvedSelection: PreferencesSection {
    PreferencesSection(rawValue: selectionRawValue) ?? .general
  }

  private var selectionBinding: Binding<PreferencesSection> {
    Binding(
      get: { resolvedSelection },
      set: { selectionRawValue = $0.rawValue }
    )
  }
}

#Preview {
  ContentView(stateManager: StateManager())
}
