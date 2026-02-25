import SwiftUI

struct SidebarItem {
  let title: String
  let icon: String
  let color: Color
}

struct CustomSidebar: View {
  @Binding var selection: String

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Top padding for macOS traffic light buttons
        Spacer().frame(height: 30)

        // Uncategorized Top Item
        renderItem(SidebarItem(title: "General", icon: "gearshape.fill", color: .purple))

        // Group 1
        VStack(alignment: .leading, spacing: 4) {
          Text("Focus & Wellbeing")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSectionHeader)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

          renderItem(SidebarItem(title: "Break Schedule", icon: "leaf.fill", color: .pink))
          renderItem(SidebarItem(title: "Smart Pause", icon: "pause.fill", color: .pink))
          renderItem(SidebarItem(title: "Wellness Reminders", icon: "heart.fill", color: .pink))
        }

        // Group 2
        VStack(alignment: .leading, spacing: 4) {
          Text("Personalize")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSectionHeader)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

          renderItem(SidebarItem(title: "Appearance", icon: "paintbrush.fill", color: .pink))
          renderItem(SidebarItem(title: "Sound Effects", icon: "speaker.wave.2.fill", color: .pink))
          renderItem(SidebarItem(title: "Keyboard Shortcuts", icon: "command", color: .orange))
        }

        // Group 3
        VStack(alignment: .leading, spacing: 4) {
          Text("Power Users")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSectionHeader)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

          renderItem(SidebarItem(title: "iPhone Sync", icon: "iphone", color: .orange))
          renderItem(
            SidebarItem(title: "Automation", icon: "arrow.triangle.2.circlepath", color: .orange))
        }

        // Group 4
        VStack(alignment: .leading, spacing: 4) {
          Text("LookAway")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSectionHeader)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

          renderItem(SidebarItem(title: "About", icon: "info.circle.fill", color: .yellow))
          renderItem(SidebarItem(title: "Insights", icon: "chart.bar.fill", color: .orange))
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 30)
    }
    .frame(width: 240)
    .background(Theme.sidebarBG)
  }

  private func renderItem(_ item: SidebarItem) -> some View {
    Button(
      action: { selection = item.title },
      label: {
        HStack(spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(item.color)
              .frame(width: 24, height: 24)
            Image(systemName: item.icon)
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white)
          }

          Text(item.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(selection == item.title ? .white : .white.opacity(0.8))

          Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selection == item.title ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        // Fix text highlighting jitter on click
        .contentShape(Rectangle())
      }
    )
    .buttonStyle(.plain)
  }
}
