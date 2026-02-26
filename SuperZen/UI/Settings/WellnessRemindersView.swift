import SwiftUI

struct WellnessRemindersView: View {
  @AppStorage(SettingKey.postureEnabled) var postureEnabled = true
  @AppStorage(SettingKey.postureFrequency) var postureFrequency: Double = 600
  @AppStorage(SettingKey.blinkEnabled) var blinkEnabled = true
  @AppStorage(SettingKey.blinkFrequency) var blinkFrequency: Double = 300
  @AppStorage(SettingKey.waterEnabled) var waterEnabled = true
  @AppStorage(SettingKey.waterFrequency) var waterFrequency: Double = 1200
  @AppStorage(SettingKey.affirmationEnabled) var affirmationEnabled = true
  @AppStorage(SettingKey.affirmationFrequency) var affirmationFrequency: Double = 3600
  @AppStorage(SettingKey.focusIdleThreshold) var focusIdleThreshold: Double = 20
  @AppStorage(SettingKey.interruptionThreshold) var interruptionThreshold: Double = 30
  @AppStorage("dimScreenWellness") var dimScreen = true

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 20) {
        WellnessCard(
          title: "Posture",
          subtitle: "Sit up straight and relax your shoulders.",
          emoji: "🧘‍♂️", color: .pink, enabled: $postureEnabled, freq: $postureFrequency,
          freqOptions: defaultFreqOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .posture) })

        WellnessCard(
          title: "Blink",
          subtitle: "Keep your eyes hydrated by blinking.",
          emoji: "👁️", color: .blue, enabled: $blinkEnabled, freq: $blinkFrequency,
          freqOptions: defaultFreqOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .blink) })
      }

      HStack(spacing: 20) {
        WellnessCard(
          title: "Drink Water",
          subtitle: "Stay hydrated for better mental focus.",
          emoji: "💧", color: .cyan, enabled: $waterEnabled, freq: $waterFrequency,
          freqOptions: defaultFreqOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .water) })

        WellnessCard(
          title: "Affirmations",
          subtitle: "A motivational boost to keep you going.",
          emoji: "⚡️", color: .yellow, enabled: $affirmationEnabled,
          freq: $affirmationFrequency,
          freqOptions: [
            ("15 minutes", 900),
            ("30 minutes", 1800),
            ("1 hour", 3600),
            ("2 hours", 7200),
          ],
          onPreview: { WellnessManager.shared.triggerPreview(type: .affirmation) })
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Common settings")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Dim screen on reminders") {
            Toggle("", isOn: $dimScreen).toggleStyle(.switch).tint(Theme.accent)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Idle cutoff (focus telemetry)") {
            ZenDurationPicker(
              title: "Idle cutoff",
              value: $focusIdleThreshold,
              options: [
                ("10 seconds", 10),
                ("20 seconds", 20),
                ("30 seconds", 30),
                ("1 minute", 60),
              ]
            )
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Interruption threshold") {
            ZenDurationPicker(
              title: "Interruption threshold",
              value: $interruptionThreshold,
              options: [
                ("20 seconds", 20),
                ("30 seconds", 30),
                ("45 seconds", 45),
                ("1 minute", 60),
              ]
            )
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Force reset timers after break") {
            Toggle("", isOn: .constant(true)).toggleStyle(.switch).tint(Theme.accent).disabled(
              true)
          }
        }
      }

      Spacer()
    }
  }

  private var defaultFreqOptions: [(String, Double)] {
    [
      ("10 minutes", 600),
      ("20 minutes", 1200),
      ("30 minutes", 1800),
      ("45 minutes", 2700),
      ("1 hour", 3600),
    ]
  }
}

// Updated WellnessCard to accept custom frequency options
struct WellnessCard: View {
  let title: String
  let subtitle: String
  let emoji: String
  let color: Color
  @Binding var enabled: Bool
  @Binding var freq: Double
  let freqOptions: [(String, Double)]
  let onPreview: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title).font(.headline).foregroundColor(Theme.textPrimary)
        Spacer()
        Button(action: onPreview) {
          Image(systemName: "play.circle.fill").foregroundColor(Theme.textSecondary)
        }.buttonStyle(.plain)
      }

      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.1))
        Text(emoji).font(.system(size: 50))
      }.frame(height: 100)

      VStack(spacing: 0) {
        ZenRow(title: "Enabled") { Toggle("", isOn: $enabled).toggleStyle(.switch).tint(color) }
          .padding(.horizontal, -16)
        Divider().background(Color.white.opacity(0.05))
        ZenRow(title: "Every") {
          ZenDurationPicker(
            title: title,
            value: $freq,
            options: freqOptions
          )
        }.padding(.horizontal, -16)
      }
    }
    .padding(16)
    .background(.regularMaterial, in: shape)
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(.quaternary, lineWidth: 1))
  }
}
