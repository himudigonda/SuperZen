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
      VStack(alignment: .leading, spacing: 12) {
        Text("Break screen")
          .font(.headline)
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

          ZenRowDivider()

          ZenRow(title: "Blur background") {
            Toggle("", isOn: $blurBackground).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Alerts positioning")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Reminder alert") {
            Toggle("", isOn: $reminderEnabled).toggleStyle(.switch).tint(.blue)
          }
          ZenRowDivider()
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
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack(alignment: .topTrailing) {
          ZStack {
            shape.fill(.thinMaterial)
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
                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
            }
          }
          .frame(width: 100, height: 70)
          .clipShape(shape)
          .overlay(
            shape.stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
          )
          .glassEffect(.regular, in: shape)

          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(Theme.accent)
              .background(Circle().fill(Color.white))
              .padding(5)
          }
        }
        .frame(width: 100)

        Text(title)
          .font(.system(size: 11))
          .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
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
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack(alignment: indicatorAlignment) {
          shape.fill(.thinMaterial)
          RoundedRectangle(cornerRadius: 3)
            .fill(.primary.opacity(isSelected ? 0.7 : 0.3))
            .frame(width: 44, height: 9)
            .padding(.top, 10)
            .padding(.leading, pos == "left" ? 10 : 0)
            .padding(.trailing, pos == "right" ? 10 : 0)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .overlay(shape.stroke(isSelected ? Theme.accent : .clear, lineWidth: 2))
        .overlay(shape.stroke(Theme.surfaceStroke.opacity(0.72), lineWidth: isSelected ? 0 : 1))
        .glassEffect(.regular, in: shape)

        Text(title)
          .font(.system(size: 11))
          .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
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
