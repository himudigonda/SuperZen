import SwiftUI

struct CustomSidebar: View {
  @Binding var selection: PreferencesSection?

  var body: some View {
    List(selection: $selection) {
      Section {
        row(.general)
      }

      Section("Focus & Wellbeing") {
        row(.breakSchedule)
        row(.wellnessReminders)
      }

      Section("Personalize") {
        row(.appearance)
        row(.soundEffects)
        row(.keyboardShortcuts)
      }

      Section("SuperZen") {
        row(.about)
        row(.insights)
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .background(.ultraThinMaterial)
    .navigationTitle("Settings")
  }

  private func row(_ section: PreferencesSection) -> some View {
    NavigationLink(value: section) {
      Label(section.title, systemImage: section.icon)
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
