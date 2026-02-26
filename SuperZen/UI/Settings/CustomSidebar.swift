import SwiftUI

struct CustomSidebar: View {
  @Binding var selection: PreferencesSection

  var body: some View {
    ScrollView(.vertical) {
      LazyVStack(alignment: .leading, spacing: 18) {
        ForEach(PreferencesSection.sidebarGroups) { group in
          VStack(alignment: .leading, spacing: 8) {
            if let title = group.title {
              Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSectionHeader)
                .textCase(nil)
                .padding(.horizontal, 8)
            }
            VStack(spacing: 6) {
              ForEach(group.sections) { section in
                row(section)
              }
            }
          }
        }
      }
      .padding(.horizontal, 10)
      .padding(.top, 14)
      .padding(.bottom, 18)
    }
    .background(ZenSidebarBackground())
    .navigationTitle("Settings")
  }

  private func row(_ section: PreferencesSection) -> some View {
    Button {
      guard selection != section else { return }
      withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
        selection = section
      }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: section.icon)
          .font(.system(size: 14, weight: .bold))
          .frame(width: 18)
        Text(section.title)
          .font(.system(size: 14, weight: .semibold))
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .foregroundStyle(selection == section ? Theme.textPrimary : Theme.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        shape.fill(selection == section ? Theme.accent.opacity(0.18) : Color.clear)
        shape.stroke(
          selection == section ? Theme.accent.opacity(0.44) : Theme.pillStroke.opacity(0.35),
          lineWidth: 1
        )
      }
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
  }
}

struct SidebarGroup: Identifiable {
  let id: String
  let title: String?
  let sections: [PreferencesSection]
}

enum PreferencesSection: String, CaseIterable, Identifiable, Hashable {
  case general = "General"
  case breakSchedule = "Break Schedule"
  case wellnessReminders = "Wellness Reminders"
  case appearance = "Appearance"
  case soundEffects = "Sound Effects"
  case keyboardShortcuts = "Keyboard Shortcuts"
  case advanced = "Advanced"
  case about = "About"
  case insights = "Insights"

  var id: String { rawValue }
  var title: String { rawValue }

  static let sidebarGroups: [SidebarGroup] = [
    SidebarGroup(id: "core", title: nil, sections: [.general]),
    SidebarGroup(
      id: "focus-wellbeing",
      title: "Focus & Wellbeing",
      sections: [.breakSchedule, .wellnessReminders]
    ),
    SidebarGroup(
      id: "personalize",
      title: "Personalize",
      sections: [.appearance, .soundEffects, .keyboardShortcuts, .advanced]
    ),
    SidebarGroup(id: "superzen", title: "SuperZen", sections: [.about, .insights]),
  ]

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
    case .advanced:
      return "slider.horizontal.3"
    case .about:
      return "info.circle.fill"
    case .insights:
      return "chart.bar.fill"
    }
  }
}
