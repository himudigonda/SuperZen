import SwiftUI

struct SoundEffectsView: View {
  @State private var volume: Double = 0.8
  @State private var breakStart: String = SettingsCatalog.soundBreakStartDefault
  @State private var breakEnd: String = SettingsCatalog.soundBreakEndDefault
  @State private var soundNudge: String = SettingsCatalog.soundNudgeDefault

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Volume")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: String(localized: "Master volume", comment: "Sound settings row title")) {
            Slider(value: $volume, in: 0...1)
              .frame(width: 150)
              .tint(.blue)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Sound Events")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          SoundEventRow(
            title: String(localized: "Break starts", comment: "Sound event row title"),
            selection: $breakStart, volume: volume)
          ZenRowDivider()
          SoundEventRow(
            title: String(localized: "Break ends", comment: "Sound event row title"),
            selection: $breakEnd, volume: volume)
          ZenRowDivider()
          SoundEventRow(
            title: String(localized: "Wellness nudge", comment: "Sound event row title"),
            selection: $soundNudge, volume: volume)
        }
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
  /// Live (possibly unsaved) draft volume from the parent screen — passed through so preview
  /// playback reflects a slider drag immediately, not just after Save.
  let volume: Double

  private let sounds = SoundManager.availableSounds

  var body: some View {
    ZenRow(title: title) {
      HStack(spacing: 12) {
        Button(action: { SoundManager.shared.preview(selection, volume: Float(volume)) }) {
          Image(systemName: "play.fill")
            .font(.system(size: 10))
            .padding(6)
            .background {
              Circle().fill(.thinMaterial)
              Circle().fill(Theme.surfaceTintTop.opacity(0.75))
            }
            .overlay(Circle().stroke(Theme.pillStroke, lineWidth: 1))
            .clipShape(Circle())
            .foregroundColor(Theme.textPrimary)
        }
        .buttonStyle(.plain)

        Menu {
          ForEach(sounds, id: \.self) { name in
            Button(name) { selection = name }
          }
        } label: {
          ZenPickerPill(text: selection)
        }
        .zenMenuStyle()
      }
    }
  }
}
