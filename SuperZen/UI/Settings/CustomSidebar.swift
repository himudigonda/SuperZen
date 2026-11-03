import SwiftUI

struct CustomSidebar: View {
  static let drawerWidth: CGFloat = 264
  static let railWidth: CGFloat = 104

  @Binding var selection: PreferencesSection
  @Binding var isCollapsed: Bool

  init(selection: Binding<PreferencesSection>, isCollapsed: Binding<Bool> = .constant(false)) {
    self._selection = selection
    self._isCollapsed = isCollapsed
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView(.vertical) {
        if isCollapsed {
          rail
        } else {
          drawer
        }
      }
      .scrollIndicators(.never)
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(ZenSidebarBackground())
  }

  private var toggleLabel: String {
    isCollapsed
      ? String(localized: "Expand sidebar", comment: "Navigation drawer: expand button")
      : String(localized: "Collapse sidebar", comment: "Navigation drawer: collapse button")
  }

  private var toggle: some View {
    Button {
      isCollapsed.toggle()
    } label: {
      Image(systemName: "sidebar.left")
    }
    .buttonStyle(ZenIconButtonStyle(kind: .standard, size: 32))
    .zenTooltip(toggleLabel)
    .accessibilityLabel(toggleLabel)
  }

  @ViewBuilder private var header: some View {
    if isCollapsed {
      VStack(spacing: 0) {
        Color.clear.frame(height: 36)
        toggle
      }
      .frame(maxWidth: .infinity)
      .padding(.bottom, ZenSpacing.sm)
      .contentShape(Rectangle())
      .gesture(WindowDragGesture())
    } else {
      HStack {
        Spacer(minLength: 0)
        toggle
      }
      .padding(.horizontal, ZenSpacing.sm)
      .frame(height: 52)
      .contentShape(Rectangle())
      .gesture(WindowDragGesture())
    }
  }

  private var drawer: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.md) {
      ForEach(PreferencesSection.sidebarGroups) { group in
        VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
          if let title = group.title {
            Text(title)
              .font(ZenFont.titleSmall)
              .foregroundStyle(ZenColor.onSurfaceVariant)
              .padding(.horizontal, ZenSpacing.md)
              .frame(height: 32)
              .accessibilityAddTraits(.isHeader)
          }
          ForEach(group.sections) { section in
            ZenDrawerItem(
              title: section.localizedTitle,
              systemImage: section.icon,
              isSelected: selection == section
            ) {
              selection = section
            }
          }
        }
      }
    }
    .padding(.horizontal, ZenSpacing.sm)
    .padding(.bottom, ZenSpacing.md)
  }

  private var rail: some View {
    VStack(spacing: ZenSpacing.xs) {
      ForEach(PreferencesSection.allCases) { section in
        ZenRailItem(
          title: section.localizedTitle,
          systemImage: section.icon,
          isSelected: selection == section
        ) {
          selection = section
        }
      }
    }
    .padding(.horizontal, ZenSpacing.xxs)
    .padding(.bottom, ZenSpacing.md)
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
    case .general: return "gearshape"
    case .breakSchedule: return "leaf"
    case .wellnessReminders: return "heart"
    case .appearance: return "paintbrush"
    case .soundEffects: return "speaker.wave.2"
    case .keyboardShortcuts: return "command"
    case .advanced: return "slider.horizontal.3"
    case .about: return "info.circle"
    case .insights: return "chart.bar"
    }
  }
}
