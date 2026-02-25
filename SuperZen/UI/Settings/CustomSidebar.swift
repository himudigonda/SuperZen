import SwiftUI

struct CustomSidebar: View {
  @Binding var selection: String

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Spacer().frame(height: 30)

        renderItem(SidebarItem(title: "General", icon: "gearshape.fill", color: .purple))

        VStack(alignment: .leading, spacing: 4) {
          sidebarHeader("Focus & Wellbeing")
          renderItem(SidebarItem(title: "Break Schedule", icon: "leaf.fill", color: .pink))
          renderItem(SidebarItem(title: "Wellness Reminders", icon: "heart.fill", color: .pink))
        }

        VStack(alignment: .leading, spacing: 4) {
          sidebarHeader("Personalize")
          renderItem(SidebarItem(title: "Appearance", icon: "paintbrush.fill", color: .pink))
          renderItem(SidebarItem(title: "Sound Effects", icon: "speaker.wave.2.fill", color: .pink))
          renderItem(SidebarItem(title: "Keyboard Shortcuts", icon: "command", color: .orange))
        }

        VStack(alignment: .leading, spacing: 4) {
          sidebarHeader("SuperZen")
          renderItem(SidebarItem(title: "About", icon: "info.circle.fill", color: .yellow))
          renderItem(SidebarItem(title: "Insights", icon: "chart.bar.fill", color: .orange))
        }
      }
      .padding(.horizontal, 12)
    }
    .frame(width: 240)
    .background(Theme.sidebarBG)
  }

  private func sidebarHeader(_ title: String) -> some View {
    Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(Theme.textSectionHeader)
      .padding(.horizontal, 12).padding(.bottom, 4)
  }

  private func renderItem(_ item: SidebarItem) -> some View {
    Button(action: { selection = item.title }) {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 6).fill(item.color).frame(width: 24, height: 24)
          Image(systemName: item.icon).font(.system(size: 12, weight: .bold)).foregroundColor(
            .white)
        }
        Text(item.title).font(.system(size: 13, weight: .medium)).foregroundColor(
          selection == item.title ? .white : .white.opacity(0.8))
        Spacer()
      }.padding(.horizontal, 10).padding(.vertical, 6)
    }.buttonStyle(SidebarButtonStyle(isSelected: selection == item.title))
  }
}

struct SidebarItem: Identifiable {
  let id = UUID()
  let title: String
  let icon: String
  let color: Color
}

struct SidebarButtonStyle: ButtonStyle {
  var isSelected: Bool
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
      .cornerRadius(8)
      .contentShape(Rectangle())
  }
}
