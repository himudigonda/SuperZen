import SwiftUI

struct ContentView: View {
  let stateManager: StateManager
  @SceneStorage("superzen.preferences.selection")
  private var selectionRawValue: String = PreferencesSection.general.rawValue
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

  var body: some View {
    Group {
      if hasCompletedOnboarding {
        mainInterface
      } else {
        OnboardingView()
          .transition(.opacity)
      }
    }
    .zenThemed()
  }

  private var mainInterface: some View {
    let selection = resolvedSelection
    return NavigationSplitView {
      CustomSidebar(selection: selectionBinding)
        .navigationSplitViewColumnWidth(min: 232, ideal: 260, max: 280)
    } detail: {
      detailView(for: selection)
        .navigationTitle(selection.localizedTitle)
    }
    .background(ZenCanvasBackground())
    .frame(minWidth: 850, idealWidth: 900, minHeight: 600, idealHeight: 650)
    .zenAnimation(.quick, value: selectionRawValue)
    .onAppear {
      if let window = NSApp.windows.first(where: {
        $0.identifier?.rawValue == "main" || $0.title == "SuperZen"
      }) {
        window.center()
      }
    }
  }

  @ViewBuilder
  private func detailView(for section: PreferencesSection) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: ZenSpacing.xl) {
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
      .padding(ZenSpacing.xxl)
      .padding(.bottom, ZenSpacing.xxxl)
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
