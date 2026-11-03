import SwiftUI

struct SoundEffectsView: View {
  @AppStorage(SettingKey.soundVolume) private var volume: Double = 0.8
  @AppStorage(SettingKey.soundBreakStart) private var breakStart: String = SettingsCatalog.soundBreakStartDefault
  @AppStorage(SettingKey.soundBreakEnd) private var breakEnd: String = SettingsCatalog.soundBreakEndDefault
  @AppStorage(SettingKey.soundNudge) private var soundNudge: String = SettingsCatalog.soundNudgeDefault

  var body: some View {
    SettingsPage {
      CardSection("Volume") {
        SettingRow(String(localized: "Master volume", comment: "Sound settings row title")) {
          ZenSlider(
            String(localized: "Master volume", comment: "Sound settings row title"),
            value: $volume, in: 0...1
          )
          .frame(width: 160)
        }
      }

      CardSection("Sound Events") {
        SoundEventRow(
          title: String(localized: "Break starts", comment: "Sound event row title"),
          selection: $breakStart, volume: volume)
        CardDivider()
        SoundEventRow(
          title: String(localized: "Break ends", comment: "Sound event row title"),
          selection: $breakEnd, volume: volume)
        CardDivider()
        SoundEventRow(
          title: String(localized: "Wellness nudge", comment: "Sound event row title"),
          selection: $soundNudge, volume: volume)
      }

    }
  }
}

struct SoundEventRow: View {
  let title: String
  @Binding var selection: String
  let volume: Double

  var body: some View {
    SettingRow(title) {
      HStack(spacing: ZenSpacing.sm) {
        Button {
          SoundManager.shared.preview(selection, volume: Float(volume))
        } label: {
          Image(systemName: "play.fill")
            .font(ZenFont.iconSmall)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(ZenIconButtonStyle(kind: .tonal, size: 32))
        .accessibilityLabel(
          String(localized: "Preview \(title) sound", comment: "Sound preview button"))

        MenuPicker(
          title, selection: $selection, options: SoundManager.availableSounds, label: { $0 })
      }
    }
  }
}
