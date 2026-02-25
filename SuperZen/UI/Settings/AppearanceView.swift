import SwiftUI

struct AppearanceView: View {
  @AppStorage("breakBackground") var bgType = "Wallpaper"
  @AppStorage("blurBackground") var blurBackground = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Break screen").font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          VStack(alignment: .leading, spacing: 12) {
            Text("Background").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
            HStack(spacing: 12) {
              AppearanceOption(title: "Custom Image", icon: "photo.badge.plus", isSelected: false)
              AppearanceOption(
                title: "Wallpaper", icon: "desktopcomputer", isSelected: bgType == "Wallpaper"
              )
              .onTapGesture { bgType = "Wallpaper" }
              AppearanceOption(
                title: "Gradient", icon: "square.stack.3d.down.right.fill",
                isSelected: bgType == "Gradient"
              )
              .onTapGesture { bgType = "Gradient" }
            }
          }.padding(16)

          Divider().background(Color.white.opacity(0.05))
          ZenRow(title: "Blur background") {
            Toggle("", isOn: $blurBackground).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Alerts positioning").font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
        HStack(spacing: 12) {
          PositionCard(title: "Top left")
          PositionCard(title: "Top center", isSelected: true)
          PositionCard(title: "Top right")
        }
      }
    }
  }
}

struct AppearanceOption: View {
  let title: String
  let icon: String
  let isSelected: Bool
  var body: some View {
    VStack {
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05))
        Image(systemName: icon).font(.title2)
          .foregroundColor(isSelected ? .blue : Theme.textPrimary)
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.blue)
            .background(Color.white.clipShape(Circle()))
            .offset(x: 35, y: -25)
        }
      }.frame(width: 100, height: 70)
      Text(title).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
    }
  }
}

struct PositionCard: View {
  let title: String
  var isSelected: Bool = false
  var body: some View {
    VStack {
      RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05))
        .frame(height: 80)
        .overlay(
          RoundedRectangle(cornerRadius: 8).stroke(
            isSelected ? Color.blue : Color.clear, lineWidth: 2
          )
        )
      Text(title).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
    }
  }
}
