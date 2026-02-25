import SwiftUI

struct SoundEffectsView: View {
  @AppStorage("masterVolume") var volume: Double = 0.8
  @AppStorage("soundBreakStart") var breakStart = "Hero"
  @AppStorage("soundBreakEnd") var breakEnd = "Glass"
  @AppStorage("soundNudge") var soundNudge = "Pop"

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
          SoundEventRow(title: "Break starts", selection: $breakStart, event: .breakStart)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          SoundEventRow(title: "Break ends", selection: $breakEnd, event: .breakEnd)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          SoundEventRow(title: "Wellness nudge", selection: $soundNudge, event: .nudge)
        }
      }

      Spacer()
    }
  }
}

struct SoundEventRow: View {
  let title: String
  @Binding var selection: String
  let event: SoundManager.SoundEvent

  var body: some View {
    ZenRow(title: title) {
      HStack(spacing: 12) {
        Button(
          action: {
            SoundManager.shared.play(event)
          },
          label: {
            Image(systemName: "play.fill")
              .font(.system(size: 10))
              .padding(6)
              .background(Color.white.opacity(0.1))
              .clipShape(Circle())
              .foregroundColor(Theme.textPrimary)
          }
        )
        .buttonStyle(.plain)

        Menu {
          Button("Hero") { selection = "Hero" }
          Button("Glass") { selection = "Glass" }
          Button("Ping") { selection = "Ping" }
          Button("Purr") { selection = "Purr" }
          Button("Pop") { selection = "Pop" }
        } label: {
          ZenPickerPill(text: selection)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
      }
    }
  }
}
