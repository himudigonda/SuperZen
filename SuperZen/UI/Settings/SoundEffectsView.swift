import SwiftUI

struct SoundEffectsView: View {
  @AppStorage(SettingKey.soundVolume) var volume: Double = 0.8
  @AppStorage(SettingKey.soundBreakStart) var breakStart = "Hero"
  @AppStorage(SettingKey.soundBreakEnd) var breakEnd = "Glass"
  @AppStorage(SettingKey.soundNudge) var soundNudge = "Pop"

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Volume")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)

        ZenCard {
          ZenRow(title: "Master volume") {
            Slider(value: $volume, in: 0...1)
              .frame(width: 150)
              .tint(.blue)
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Sound Events")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)

        ZenCard {
          SoundEventRow(title: "Break starts", selection: $breakStart)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          SoundEventRow(title: "Break ends", selection: $breakEnd)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          SoundEventRow(title: "Wellness nudge", selection: $soundNudge)
        }
      }

      Spacer()
    }
  }
}

struct SoundEventRow: View {
  let title: String
  @Binding var selection: String

  private let sounds = SoundManager.availableSounds

  var body: some View {
    ZenRow(title: title) {
      HStack(spacing: 12) {
        // Preview button plays exactly what is currently selected
        Button(action: { SoundManager.shared.preview(selection) }) {
          Image(systemName: "play.fill")
            .font(.system(size: 10))
            .padding(6)
            .background(Color.white.opacity(0.1))
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
        .menuStyle(.borderlessButton)
        .fixedSize()
      }
    }
  }
}
