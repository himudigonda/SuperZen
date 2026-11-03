import SwiftUI

struct CustomSidebar: View {
  @Binding var selection: PreferencesSection

  var body: some View {
    ScrollView(.vertical) {
      LazyVStack(alignment: .leading, spacing: ZenSpacing.lg) {
        ForEach(PreferencesSection.sidebarGroups) { group in
          VStack(alignment: .leading, spacing: ZenSpacing.xs) {
            if let title = group.title {
              Text(title)
                .font(ZenFont.captionEmphasized)
                .foregroundStyle(ZenColor.textTertiary)
                .padding(.horizontal, ZenSpacing.xs)
                .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: ZenSpacing.xxs) {
              ForEach(group.sections) { section in
                SidebarRow(section: section, selection: $selection)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, ZenSpacing.sm)
      .padding(.top, ZenSpacing.md)
      .padding(.bottom, ZenSpacing.lg)
    }
    .background(ZenSidebarBackground())
    .navigationTitle("Settings")
  }
}

private struct SidebarRow: View {
  let section: PreferencesSection
  @Binding var selection: PreferencesSection
  @State private var isHovered = false

  var body: some View {
    let isSelected = selection == section
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    Button {
      selection = section
    } label: {
      HStack(spacing: ZenSpacing.sm) {
        Image(systemName: section.icon)
          .font(ZenFont.body)
          .foregroundStyle(isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.textSecondary))
          .frame(width: ZenSpacing.lg)
          .accessibilityHidden(true)
        Text(section.localizedTitle)
          .font(isSelected ? ZenFont.bodyEmphasized : ZenFont.body)
          .foregroundStyle(isSelected || isHovered ? ZenColor.textPrimary : ZenColor.textSecondary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, ZenSpacing.sm)
      .padding(.vertical, ZenSpacing.xs - 2)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(shape)
      .background {
        if isSelected {
          shape.fill(ZenColor.accent.opacity(0.18))
        } else if isHovered {
          shape.fill(ZenColor.textPrimary.opacity(0.06))
        }
      }
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
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

  var localizedTitle: String {
    switch self {
    case .general: return String(localized: "General", comment: "Settings sidebar section")
    case .breakSchedule:
      return String(localized: "Break Schedule", comment: "Settings sidebar section")
    case .wellnessReminders:
      return String(localized: "Wellness Reminders", comment: "Settings sidebar section")
    case .appearance: return String(localized: "Appearance", comment: "Settings sidebar section")
    case .soundEffects:
      return String(localized: "Sound Effects", comment: "Settings sidebar section")
    case .keyboardShortcuts:
      return String(localized: "Keyboard Shortcuts", comment: "Settings sidebar section")
    case .advanced: return String(localized: "Advanced", comment: "Settings sidebar section")
    case .about: return String(localized: "About", comment: "Settings sidebar section")
    case .insights: return String(localized: "Insights", comment: "Settings sidebar section")
    }
  }

  static let sidebarGroups: [SidebarGroup] = [
    SidebarGroup(id: "core", title: nil, sections: [.general]),
    SidebarGroup(
      id: "focus-wellbeing",
      title: String(localized: "Focus & Wellbeing", comment: "Settings sidebar group"),
      sections: [.breakSchedule, .wellnessReminders]
    ),
    SidebarGroup(
      id: "personalize",
      title: String(localized: "Personalize", comment: "Settings sidebar group"),
      sections: [.appearance, .soundEffects, .keyboardShortcuts, .advanced]
    ),
    SidebarGroup(id: "superzen", title: "SuperZen", sections: [.about, .insights]),
  ]

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .breakSchedule: return "leaf.fill"
    case .wellnessReminders: return "heart.fill"
    case .appearance: return "paintbrush.fill"
    case .soundEffects: return "speaker.wave.2.fill"
    case .keyboardShortcuts: return "command"
    case .advanced: return "slider.horizontal.3"
    case .about: return "info.circle.fill"
    case .insights: return "chart.bar.fill"
    }
  }
}
