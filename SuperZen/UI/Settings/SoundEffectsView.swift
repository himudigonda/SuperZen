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
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

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
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          SoundEventRow(title: "Break starts", selection: $breakStart)
          ZenRowDivider()
          SoundEventRow(title: "Break ends", selection: $breakEnd)
          ZenRowDivider()
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
        Button(action: { SoundManager.shared.preview(selection) }) {
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
