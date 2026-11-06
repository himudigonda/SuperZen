import AppKit
import ImageIO
import SuperZenCore
import SwiftUI
import UniformTypeIdentifiers

struct AppearanceView: View {
  let stateManager: StateManager
  @AppStorage(SettingKey.breakBackground) private var bgType: String = SettingsCatalog.breakBackgroundDefault
  @AppStorage(SettingKey.blurBackground) private var blurBackground = true
  @AppStorage(SettingKey.breakTipsEnabled) private var breakTipsEnabled = true
  @AppStorage(SettingKey.breakPresentation) private var breakPresentation: String = SettingsCatalog
    .breakPresentationDefault
  @AppStorage(SettingKey.alertPosition) private var alertPosition: String = SettingsCatalog.alertPositionDefault
  @AppStorage(SettingKey.reminderEnabled) private var reminderEnabled = true
  @AppStorage(SettingKey.reminderDuration) private var reminderDuration: Double = SettingsCatalog
    .reminderDurationDefault
  @AppStorage(SettingKey.customImagePath) private var customPath = ""
  @AppStorage(SettingKey.uiAccentPalette) private var accentPalette: String = SettingsCatalog.accentPaletteDefault
  @AppStorage(SettingKey.uiContrastProfile) private var contrastProfile: String = SettingsCatalog.contrastProfileDefault
  @State private var wallpaperPreview: CGImage?

  private var presentationIssues: [SettingsIssue] {
    SettingsValidation.issues(in: .standard).filter { $0.section == .appearance }
  }

  var body: some View {
    SettingsPage {
      CardSection("Interface style") {
        VStack(alignment: .leading, spacing: ZenSpacing.md) {
          Text("Accent palette")
            .font(ZenFont.bodyMedium)
            .foregroundStyle(ZenColor.onSurfaceVariant)
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
        SettingRow(
          String(localized: "Break style", comment: "Appearance settings row title"),
          subtitle: String(
            localized: "Show breaks full screen, or as a small banner that never blocks your work",
            comment: "Appearance settings row subtitle for break style")
        ) {
          MenuPicker(
            String(localized: "Break style", comment: "Appearance settings row title"),
            selection: $breakPresentation,
            options: SettingsCatalog.breakPresentationOptions,
            label: { SettingsCatalog.breakPresentationDisplayName($0) })
        }
        ForEach(presentationIssues, id: \.self) { issue in
          CardDivider()
          ValidationNote(issue.message)
        }
        CardDivider()
        VStack(alignment: .leading, spacing: ZenSpacing.md) {
          Text("Background")
            .font(ZenFont.bodyMedium)
            .foregroundStyle(ZenColor.onSurfaceVariant)
          HStack(spacing: ZenSpacing.md) {
            AppearanceOption(
              title: String(localized: "Custom Image", comment: "Break screen background option"),
              isSelected: bgType == "Custom",
              action: { selectCustomImage() }
            ) {
              Image(systemName: "photo.badge.plus")
                .font(ZenFont.iconLarge)
                .foregroundStyle(bgType == "Custom" ? ZenColor.primary : ZenColor.onSurfaceVariant)
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
          if ZenBackgroundView.isCustomImageMissing(type: bgType, path: customPath) {
            ValidationNote(
              String(
                localized:
                  "The custom image can't be found, so breaks show your wallpaper. Choose it again to fix this.",
                comment: "Appearance settings note when the custom break background file is gone"))
          }
        }
        .padding(ZenSpacing.md)
        CardDivider()
        LabeledToggle(
          String(localized: "Blur background", comment: "Appearance settings row title"),
          isOn: $blurBackground)
        CardDivider()
        LabeledToggle(
          String(localized: "Show break tips", comment: "Appearance settings row title"),
          isOn: $breakTipsEnabled)
      }

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
        CardDivider()
        HStack(spacing: ZenSpacing.sm) {
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
        .padding(ZenSpacing.md)
        .disabled(!reminderEnabled)
      }
    }
    .task {
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

  private func selectCustomImage() {
    if bgType != "Custom", !customPath.isEmpty, FileManager.default.isReadableFile(atPath: customPath) {
      bgType = "Custom"
    } else {
      pickImage()
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
        .zenSurface(cornerRadius: ZenRadius.md, isSelected: isSelected, kind: .outlined)
        .overlay(alignment: .topTrailing) {
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(ZenColor.onPrimary, ZenColor.primary)
              .padding(ZenSpacing.xxs)
          }
        }
        Text(SettingsCatalog.accentPaletteDisplayName(palette.rawValue))
          .font(isSelected ? ZenFont.labelMedium : ZenFont.bodySmall)
          .foregroundStyle(isSelected ? ZenColor.onSurface : ZenColor.onSurfaceVariant)
      }
    }
    .buttonStyle(ZenCardButtonStyle(cornerRadius: ZenRadius.md))
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
          preview()
        }
        .frame(width: 100, height: 68)
        .clipShape(shape)
        .zenSurface(cornerRadius: ZenRadius.md, isSelected: isSelected, kind: .outlined)
        .overlay(alignment: .topTrailing) {
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .symbolRenderingMode(.palette)
              .foregroundStyle(ZenColor.onPrimary, ZenColor.primary)
              .padding(ZenSpacing.xxs)
          }
        }
        Text(title)
          .font(ZenFont.bodySmall)
          .foregroundStyle(isSelected ? ZenColor.onSurface : ZenColor.onSurfaceVariant)
      }
    }
    .buttonStyle(ZenCardButtonStyle(cornerRadius: ZenRadius.md))
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
          RoundedRectangle(cornerRadius: ZenRadius.xs / 2)
            .fill(isSelected ? ZenColor.primary : ZenColor.onSurfaceVariant)
            .frame(width: 44, height: ZenSpacing.xs)
            .padding(.top, ZenSpacing.sm)
            .padding(.leading, pos == "left" ? ZenSpacing.sm : 0)
            .padding(.trailing, pos == "right" ? ZenSpacing.sm : 0)
        }
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .zenSurface(cornerRadius: ZenRadius.md, isSelected: isSelected, kind: .outlined)

        Text(title)
          .font(ZenFont.bodySmall)
          .foregroundStyle(isSelected ? ZenColor.onSurface : ZenColor.onSurfaceVariant)
      }
    }
    .buttonStyle(ZenCardButtonStyle(cornerRadius: ZenRadius.md))
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
