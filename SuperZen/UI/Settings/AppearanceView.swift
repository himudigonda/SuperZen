import AppKit
import ImageIO
import SuperZenCore
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
  @State private var wallpaperPreview: CGImage?

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      CardSection("Interface style") {
        VStack(alignment: .leading, spacing: ZenSpacing.md) {
          Text("Accent palette")
            .font(ZenFont.subheadline)
            .foregroundStyle(ZenColor.textSecondary)
          HStack(spacing: ZenSpacing.md) {
            ForEach(AccentPalette.allCases) { palette in
              AccentPaletteCard(palette: palette, isSelected: accentPalette == palette.rawValue) {
                accentPalette = palette.rawValue
              }
            }
          }
        }
        .padding(ZenSpacing.md)
        CardDivider()
        SettingRow(
          String(localized: "Contrast profile", comment: "Appearance settings row title"),
          subtitle: String(
            localized: "Increase edge definition and typography contrast for readability",
            comment: "Appearance settings row subtitle for contrast profile")
        ) {
          MenuPicker(
            String(localized: "Contrast profile", comment: "Appearance settings row title"),
            selection: $contrastProfile,
            options: SettingsCatalog.contrastProfiles,
            label: { SettingsCatalog.contrastProfileDisplayName($0) })
        }
      }

      CardSection("Break screen") {
        VStack(alignment: .leading, spacing: ZenSpacing.md) {
          Text("Background")
            .font(ZenFont.subheadline)
            .foregroundStyle(ZenColor.textSecondary)
          HStack(spacing: ZenSpacing.md) {
            AppearanceOption(
              title: String(localized: "Custom Image", comment: "Break screen background option"),
              isSelected: bgType == "Custom",
              action: { pickImage() }
            ) {
              Image(systemName: "photo.badge.plus")
                .font(ZenFont.title2)
                .foregroundStyle(bgType == "Custom" ? ZenColor.accent : ZenColor.textSecondary)
            }
            AppearanceOption(
              title: String(localized: "Wallpaper", comment: "Break screen background option"),
              isSelected: bgType == "Wallpaper",
              action: { bgType = "Wallpaper" }
            ) {
              if let wallpaperPreview {
                Image(decorative: wallpaperPreview, scale: 1).resizable().scaledToFill()
              } else {
                ZenPalette.fallbackBackground
              }
            }
            AppearanceOption(
              title: String(localized: "Gradient", comment: "Break screen background option"),
              isSelected: bgType == "Gradient",
              action: { bgType = "Gradient" }
            ) {
              MeshGradient(
                width: 3, height: 3,
                points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.8, 0.2], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                colors: ZenPalette.breakAtmosphere(.casual, canSkip: true))
            }
          }
        }
        .padding(ZenSpacing.md)
        CardDivider()
        LabeledToggle(
          String(localized: "Blur background", comment: "Appearance settings row title"),
          isOn: $blurBackground)
      }

      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        CardSection("Alerts positioning") {
          LabeledToggle(
            String(localized: "Reminder alert", comment: "Appearance settings row title"),
            isOn: $reminderEnabled)
          CardDivider()
          SettingRow(String(localized: "Visible for", comment: "Appearance settings row title")) {
            DurationPicker(
              String(localized: "Reminder alert", comment: "Duration picker sheet subject"),
              value: $reminderDuration,
              options: SettingsCatalog.reminderDurationOptions)
          }
          .disabled(!reminderEnabled)
        }

        HStack(spacing: ZenSpacing.md) {
          PositionCard(
            title: String(localized: "Top left", comment: "Alert position option"),
            pos: "left", isSelected: alertPosition == "left"
          ) { selectPosition("left") }
          PositionCard(
            title: String(localized: "Top center", comment: "Alert position option"),
            pos: "center", isSelected: alertPosition == "center"
          ) { selectPosition("center") }
          PositionCard(
            title: String(localized: "Top right", comment: "Alert position option"),
            pos: "right", isSelected: alertPosition == "right"
          ) { selectPosition("right") }
        }
      }

      SettingsSaveBar(onSave: save)
    }
    .task {
      load()
      wallpaperPreview = Self.wallpaperThumbnail()
    }
  }

  private func selectPosition(_ pos: String) {
    alertPosition = pos
    if reminderEnabled {
      OverlayCoordinator.shared.previewAlert(
        for: stateManager, position: pos, duration: reminderDuration)
    }
  }

  private static func wallpaperThumbnail() -> CGImage? {
    guard let screen = NSScreen.main,
      let url = NSWorkspace.shared.desktopImageURL(for: screen),
      let source = CGImageSourceCreateWithURL(url as CFURL, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 320,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
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
  let palette: AccentPalette
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      VStack(spacing: ZenSpacing.xs) {
        LinearGradient(
          colors: palette.previewColors, startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .frame(width: 88, height: 52)
        .clipShape(shape)
        .overlay {
          shape.strokeBorder(
            isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.surfaceStroke),
            lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(ZenColor.onAccent, ZenColor.accent)
              .padding(ZenSpacing.xxs)
          }
        }
        Text(SettingsCatalog.accentPaletteDisplayName(palette.rawValue))
          .font(isSelected ? ZenFont.captionEmphasized : ZenFont.caption)
          .foregroundStyle(isSelected ? ZenColor.textPrimary : ZenColor.textSecondary)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(SettingsCatalog.accentPaletteDisplayName(palette.rawValue))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

struct AppearanceOption<Preview: View>: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void
  @ViewBuilder let preview: () -> Preview

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      VStack(spacing: ZenSpacing.xs) {
        ZStack {
          shape.fill(.thinMaterial)
          preview()
        }
        .frame(width: 100, height: 68)
        .clipShape(shape)
        .overlay {
          shape.strokeBorder(
            isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.surfaceStroke),
            lineWidth: isSelected ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(ZenColor.onAccent, ZenColor.accent)
              .padding(ZenSpacing.xxs)
          }
        }
        Text(title)
          .font(ZenFont.caption)
          .foregroundStyle(isSelected ? ZenColor.textPrimary : ZenColor.textSecondary)
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

struct PositionCard: View {
  let title: String
  let pos: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      VStack(spacing: ZenSpacing.xs) {
        ZStack(alignment: indicatorAlignment) {
          shape.fill(.thinMaterial)
          RoundedRectangle(cornerRadius: ZenRadius.xs / 2)
            .fill(ZenColor.textPrimary.opacity(isSelected ? 0.7 : 0.3))
            .frame(width: 44, height: ZenSpacing.xs)
            .padding(.top, ZenSpacing.sm)
            .padding(.leading, pos == "left" ? ZenSpacing.sm : 0)
            .padding(.trailing, pos == "right" ? ZenSpacing.sm : 0)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .overlay {
          shape.strokeBorder(
            isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.surfaceStroke),
            lineWidth: isSelected ? 2 : 1)
        }
        .glassEffect(.regular, in: shape)

        Text(title)
          .font(ZenFont.caption)
          .foregroundStyle(isSelected ? ZenColor.textPrimary : ZenColor.textSecondary)
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var indicatorAlignment: Alignment {
    switch pos {
    case "left": return .topLeading
    case "right": return .topTrailing
    default: return .top
    }
  }
}
