import AppKit
import SwiftUI

struct ContentView: View {
  let stateManager: StateManager
  @AppStorage("superzen.preferences.selection")
  private var selectionRawValue: String = PreferencesSection.general.rawValue
  @AppStorage("superzen.preferences.drawerCollapsed")
  private var isDrawerCollapsed = false
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  @State private var isScrolled = false

  var body: some View {
    Group {
      if hasCompletedOnboarding {
        mainInterface
      } else {
        OnboardingView()
          .transition(.opacity)
          .onAppear { NSApp.activate() }
      }
    }
    .zenOverlayHost()
    .zenThemed()
  }

  private var mainInterface: some View {
    let selection = resolvedSelection
    return HStack(spacing: 0) {
      CustomSidebar(selection: selectionBinding, isCollapsed: $isDrawerCollapsed)
        .frame(width: isDrawerCollapsed ? CustomSidebar.railWidth : CustomSidebar.drawerWidth)
      VStack(spacing: 0) {
        ZenTopAppBar(selection.localizedTitle, isScrolled: isScrolled)
        detailView(for: selection)
      }
    }
    .ignoresSafeArea(.container, edges: .top)
    .background(ZenCanvasBackground())
    .navigationTitle(selection.localizedTitle)
    .frame(minWidth: 850, idealWidth: 900, minHeight: 600, idealHeight: 650)
    .zenAnimation(.quick, value: selectionRawValue)
    .zenAnimation(.emphasized, value: isDrawerCollapsed)
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
          KeyboardShortcutsView(hotkeys: stateManager.hotkeys)
        case .advanced:
          AdvancedSettingsView()
        case .about:
          AboutView()
        case .insights:
          InsightsView()
        }
        ResetSectionButton(section: section)
      }
      .padding(.horizontal, ZenSpacing.xl)
      .padding(.top, ZenSpacing.xs)
      .padding(.bottom, ZenSpacing.xxxl)
      .frame(maxWidth: ContentView.pageMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentOffset.y + geometry.contentInsets.top > 0
    } action: { _, scrolled in
      isScrolled = scrolled
    }
    .background(ZenCanvasBackground())
  }

  private static let pageMaxWidth: CGFloat = 1040

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
