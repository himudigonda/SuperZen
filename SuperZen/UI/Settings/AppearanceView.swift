import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppearanceView: View {
  @EnvironmentObject var stateManager: StateManager
  @AppStorage(SettingKey.breakBackground) var bgType = "Wallpaper"
  @AppStorage(SettingKey.blurBackground) var blurBackground = true
  @AppStorage(SettingKey.alertPosition) var alertPosition = "center"
  @AppStorage(SettingKey.reminderEnabled) var reminderEnabled = true
  @AppStorage(SettingKey.reminderDuration) var reminderDuration: Double = 10
  @AppStorage(SettingKey.customImagePath) var customPath = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      // SECTION 1: Break screen background
      VStack(alignment: .leading, spacing: 12) {
        Text("Break screen")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          VStack(alignment: .leading, spacing: 16) {
            Text("Background")
              .font(.system(size: 12))
              .foregroundColor(Theme.textSecondary)

            HStack(spacing: 16) {
              AppearanceOption(
                title: "Custom Image",
                icon: "photo.badge.plus",
                isSelected: bgType == "Custom"
              ) { pickImage() }

              AppearanceOption(
                title: "Wallpaper",
                isWallpaper: true,
                isSelected: bgType == "Wallpaper"
              ) { bgType = "Wallpaper" }

              AppearanceOption(
                title: "Gradient",
                isGradient: true,
                isSelected: bgType == "Gradient"
              ) { bgType = "Gradient" }
            }
          }
          .padding(16)

          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Blur background") {
            Toggle("", isOn: $blurBackground).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      // SECTION 2: Alerts positioning
      VStack(alignment: .leading, spacing: 12) {
        Text("Alerts positioning")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Reminder alert") {
            Toggle("", isOn: $reminderEnabled).toggleStyle(.switch).tint(.blue)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Visible for") {
            ZenDurationPicker(
              title: "Reminder alert",
              value: $reminderDuration,
              options: [("5 seconds", 5), ("10 seconds", 10), ("15 seconds", 15)]
            )
          }
        }

        HStack(spacing: 14) {
          PositionCard(title: "Top left", pos: "left", isSelected: alertPosition == "left") {
            alertPosition = "left"
            OverlayWindowManager.shared.previewFixedAlert(with: stateManager)
          }
          PositionCard(
            title: "Top center", pos: "center", isSelected: alertPosition == "center"
          ) {
            alertPosition = "center"
            OverlayWindowManager.shared.previewFixedAlert(with: stateManager)
          }
          PositionCard(title: "Top right", pos: "right", isSelected: alertPosition == "right") {
            alertPosition = "right"
            OverlayWindowManager.shared.previewFixedAlert(with: stateManager)
          }
        }
      }
    }
  }

  private func pickImage() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.image]
    if panel.runModal() == .OK {
      customPath = panel.url?.path ?? ""
      bgType = "Custom"
    }
  }
}

struct AppearanceOption: View {
  let title: String
  var icon: String?
  var isWallpaper: Bool = false
  var isGradient: Bool = false
  let isSelected: Bool
  let action: () -> Void

  private var currentWallpaper: NSImage? {
    guard let screen = NSScreen.main,
      let url = NSWorkspace.shared.desktopImageURL(for: screen)
    else { return nil }
    return NSImage(contentsOf: url)
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack(alignment: .topTrailing) {
          // Thumbnail
          ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05))
            if isWallpaper {
              if let img = currentWallpaper {
                Image(nsImage: img).resizable().scaledToFill()
              } else {
                Theme.gradientCasual
              }
            } else if isGradient {
              LinearGradient(
                colors: [.purple, .blue, .cyan, .teal, .green, .yellow, .orange, .red, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            } else if let icon = icon {
              Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .white)
            }
          }
          .frame(width: 100, height: 70)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
          )

          // Check badge
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.blue)
              .background(Circle().fill(Color.white))
              .padding(5)
          }
        }
        .frame(width: 100)

        Text(title)
          .font(.system(size: 11))
          .foregroundColor(isSelected ? .white : Theme.textSecondary)
      }
    }
    .buttonStyle(.plain)
  }
}

struct PositionCard: View {
  let title: String
  let pos: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack(alignment: indicatorAlignment) {
          RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12))
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(isSelected ? 0.7 : 0.3))
            .frame(width: 44, height: 9)
            .padding(.top, 10)
            .padding(.leading, pos == "left" ? 10 : 0)
            .padding(.trailing, pos == "right" ? 10 : 0)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )

        Text(title)
          .font(.system(size: 11))
          .foregroundColor(isSelected ? .white : Theme.textSecondary)
      }
    }
    .buttonStyle(.plain)
  }

  private var indicatorAlignment: Alignment {
    switch pos {
    case "left": return .topLeading
    case "right": return .topTrailing
    default: return .top
    }
  }
}
