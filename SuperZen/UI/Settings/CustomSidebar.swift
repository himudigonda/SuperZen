import SwiftUI

struct CustomSidebar: View {
  @Binding var selection: PreferencesSection?

  var body: some View {
    List(selection: $selection) {
      Section {
        row(.general)
      }

      Section {
        row(.breakSchedule)
        row(.wellnessReminders)
      } header: {
        Text("Focus & Wellbeing")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Theme.textSectionHeader)
          .textCase(nil)
      }

      Section {
        row(.appearance)
        row(.soundEffects)
        row(.keyboardShortcuts)
      } header: {
        Text("Personalize")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Theme.textSectionHeader)
          .textCase(nil)
      }

      Section {
        row(.about)
        row(.insights)
      } header: {
        Text("SuperZen")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Theme.textSectionHeader)
          .textCase(nil)
      }
    }
    .listStyle(.sidebar)
    .environment(\.defaultMinListRowHeight, 36)
    .scrollContentBackground(.hidden)
    .background(ZenSidebarBackground())
    .navigationTitle("Settings")
  }

  private func row(_ section: PreferencesSection) -> some View {
    NavigationLink(value: section) {
      Label {
        Text(section.title)
          .font(.system(size: 16, weight: .semibold))
      } icon: {
        Image(systemName: section.icon)
          .font(.system(size: 14, weight: .bold))
      }
    }
    .tag(Optional(section))
  }
}

enum PreferencesSection: String, CaseIterable, Identifiable {
  case general = "General"
  case breakSchedule = "Break Schedule"
  case wellnessReminders = "Wellness Reminders"
  case appearance = "Appearance"
  case soundEffects = "Sound Effects"
  case keyboardShortcuts = "Keyboard Shortcuts"
  case about = "About"
  case insights = "Insights"

  var id: String { rawValue }
  var title: String { rawValue }

  var icon: String {
    switch self {
    case .general:
      return "gearshape.fill"
    case .breakSchedule:
      return "leaf.fill"
    case .wellnessReminders:
      return "heart.fill"
    case .appearance:
      return "paintbrush.fill"
    case .soundEffects:
      return "speaker.wave.2.fill"
    case .keyboardShortcuts:
      return "command"
    case .about:
      return "info.circle.fill"
    case .insights:
      return "chart.bar.fill"
    }
  }
}
