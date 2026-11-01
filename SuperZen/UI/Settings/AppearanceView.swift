import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppearanceView: View {
  let stateManager: StateManager
  @State private var bgType: String = SettingsCatalog.breakBackgroundDefault
  @State private var blurBackground = true
  @State private var alertPosition: String = SettingsCatalog.alertPositionDefault
  @State private var reminderEnabled = true
  @State private var reminderDuration: Double = SettingsCatalog.reminderDurationDefault
  @State private var customPath = ""
  @State private var accentPalette: String = SettingsCatalog.accentPaletteDefault
  @State private var contrastProfile: String = SettingsCatalog.contrastProfileDefault

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Interface style")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          VStack(alignment: .leading, spacing: 16) {
            Text("Accent palette")
              .font(.system(size: 12))
              .foregroundColor(Theme.textSecondary)

            HStack(spacing: 14) {
              ForEach(SettingsCatalog.accentPalettes, id: \.self) { palette in
                AccentPaletteCard(
                  palette: palette,
                  isSelected: accentPalette == palette
                ) {
                  accentPalette = palette
                }
              }
            }
          }
          .padding(16)

          ZenRowDivider()

          ZenRow(
            title: String(localized: "Contrast profile", comment: "Appearance settings row title"),
            subtitle: String(
              localized: "Increase edge definition and typography contrast for readability",
              comment: "Appearance settings row subtitle for contrast profile")
          ) {
            Menu {
              ForEach(SettingsCatalog.contrastProfiles, id: \.self) { profile in
                Button(SettingsCatalog.contrastProfileDisplayName(profile)) {
                  contrastProfile = profile
                }
              }
            } label: {
              ZenPickerPill(text: SettingsCatalog.contrastProfileDisplayName(contrastProfile))
            }
            .zenMenuStyle()
          }
        }
      }

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
                title: String(localized: "Custom Image", comment: "Break screen background option"),
                icon: "photo.badge.plus",
                isSelected: bgType == "Custom"
              ) { pickImage() }

              AppearanceOption(
                title: String(localized: "Wallpaper", comment: "Break screen background option"),
                isWallpaper: true,
                isSelected: bgType == "Wallpaper"
              ) { bgType = "Wallpaper" }

              AppearanceOption(
                title: String(localized: "Gradient", comment: "Break screen background option"),
                isGradient: true,
                isSelected: bgType == "Gradient"
              ) { bgType = "Gradient" }
            }
          }
          .padding(16)

          ZenRowDivider()

          ZenRow(
            title: String(localized: "Blur background", comment: "Appearance settings row title")
          ) {
            Toggle("", isOn: $blurBackground).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Alerts positioning")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(
            title: String(localized: "Reminder alert", comment: "Appearance settings row title")
          ) {
            Toggle("", isOn: $reminderEnabled).toggleStyle(.switch).tint(.blue)
          }
          ZenRowDivider()
          ZenRow(title: String(localized: "Visible for", comment: "Appearance settings row title")) {
            ZenDurationPicker(
              title: String(localized: "Reminder alert", comment: "Duration picker sheet subject"),
              value: $reminderDuration,
              options: SettingsCatalog.reminderDurationOptions
            )
          }
        }

        HStack(spacing: 14) {
          PositionCard(
            title: String(localized: "Top left", comment: "Alert position option"),
            pos: "left", isSelected: alertPosition == "left"
          ) {
            selectPosition("left")
          }
          PositionCard(
            title: String(localized: "Top center", comment: "Alert position option"),
            pos: "center", isSelected: alertPosition == "center"
          ) {
            selectPosition("center")
          }
          PositionCard(
            title: String(localized: "Top right", comment: "Alert position option"),
            pos: "right", isSelected: alertPosition == "right"
          ) {
            selectPosition("right")
          }
        }
      }

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  /// Selects a reminder position. Only previews the alert when reminders are actually
  /// enabled — otherwise tapping a position would flash a reminder the user has turned off.
  private func selectPosition(_ pos: String) {
    alertPosition = pos
    if reminderEnabled {
      // Pass the just-tapped draft values directly — they haven't been saved to UserDefaults
      // yet, so the preview would otherwise render at the last-*saved* position/duration.
      OverlayCoordinator.shared.previewAlert(
        for: stateManager, position: pos, duration: reminderDuration)
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

  private func load() {
    let d = UserDefaults.standard
    bgType = d.string(forKey: SettingKey.breakBackground) ?? SettingsCatalog.breakBackgroundDefault
    blurBackground = d.bool(forKey: SettingKey.blurBackground)
    alertPosition =
      d.string(forKey: SettingKey.alertPosition) ?? SettingsCatalog.alertPositionDefault
    reminderEnabled = d.bool(forKey: SettingKey.reminderEnabled)
    reminderDuration = d.double(forKey: SettingKey.reminderDuration)
    customPath = d.string(forKey: SettingKey.customImagePath) ?? ""
    accentPalette =
      d.string(forKey: SettingKey.uiAccentPalette) ?? SettingsCatalog.accentPaletteDefault
    contrastProfile =
      d.string(forKey: SettingKey.uiContrastProfile) ?? SettingsCatalog.contrastProfileDefault
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(bgType, forKey: SettingKey.breakBackground)
    d.set(blurBackground, forKey: SettingKey.blurBackground)
    d.set(alertPosition, forKey: SettingKey.alertPosition)
    d.set(reminderEnabled, forKey: SettingKey.reminderEnabled)
    d.set(reminderDuration, forKey: SettingKey.reminderDuration)
    d.set(customPath, forKey: SettingKey.customImagePath)
    d.set(accentPalette, forKey: SettingKey.uiAccentPalette)
    d.set(contrastProfile, forKey: SettingKey.uiContrastProfile)
  }
}

private struct AccentPaletteCard: View {
  let palette: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    Button(action: action) {
      VStack(spacing: 8) {
        LinearGradient(
          colors: Theme.accentPreviewColors(for: palette),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .frame(width: 86, height: 52)
        .clipShape(shape)
        .overlay(
          shape.stroke(isSelected ? Theme.accent : Theme.surfaceStroke.opacity(0.75), lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(Color.white, Theme.accent)
              .padding(4)
          }
        }

        Text(SettingsCatalog.accentPaletteDisplayName(palette))
          .font(.system(size: 11, weight: isSelected ? .bold : .medium))
          .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
      }
    }
    .buttonStyle(.plain)
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
