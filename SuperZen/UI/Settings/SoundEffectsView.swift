import SwiftUI

struct SoundEffectsView: View {
  @State private var volume: Double = 0.8
  @State private var breakStart: String = SettingsCatalog.soundBreakStartDefault
  @State private var breakEnd: String = SettingsCatalog.soundBreakEndDefault
  @State private var soundNudge: String = SettingsCatalog.soundNudgeDefault

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      CardSection("Volume") {
        SettingRow(String(localized: "Master volume", comment: "Sound settings row title")) {
          Slider(value: $volume, in: 0...1) {
            Text(String(localized: "Master volume", comment: "Sound settings row title"))
          }
          .labelsHidden()
          .frame(width: 160)
          .tint(ZenColor.accent)
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

      Spacer()

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  private func load() {
    let d = UserDefaults.standard
    volume = d.double(forKey: SettingKey.soundVolume)
    breakStart =
      d.string(forKey: SettingKey.soundBreakStart) ?? SettingsCatalog.soundBreakStartDefault
    breakEnd = d.string(forKey: SettingKey.soundBreakEnd) ?? SettingsCatalog.soundBreakEndDefault
    soundNudge = d.string(forKey: SettingKey.soundNudge) ?? SettingsCatalog.soundNudgeDefault
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(volume, forKey: SettingKey.soundVolume)
    d.set(breakStart, forKey: SettingKey.soundBreakStart)
    d.set(breakEnd, forKey: SettingKey.soundBreakEnd)
    d.set(soundNudge, forKey: SettingKey.soundNudge)
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
            .font(ZenFont.controlIcon)
            .padding(ZenSpacing.xs - 2)
            .background(Circle().fill(.thinMaterial))
            .overlay(Circle().strokeBorder(ZenColor.controlStroke, lineWidth: 1))
            .foregroundStyle(ZenColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          String(localized: "Preview \(title) sound", comment: "Sound preview button"))

        MenuPicker(
          title, selection: $selection, options: SoundManager.availableSounds, label: { $0 })
      }
    }
  }
}
