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
  @AppStorage(SettingKey.dimScreenWellness) var dimScreen = true
  @AppStorage(SettingKey.quietHoursEnabled) var quietHoursEnabled = false
  @AppStorage(SettingKey.quietHoursStartMinute) var quietHoursStartMinute = 1320
  @AppStorage(SettingKey.quietHoursEndMinute) var quietHoursEndMinute = 420
  @AppStorage(SettingKey.wellnessDurationMultiplier) var wellnessDurationMultiplier: Double = 1.0

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 20) {
        WellnessCard(
          title: "Posture",
          subtitle: "Sit up straight and relax your shoulders.",
          emoji: "🧘‍♂️", color: .pink, enabled: $postureEnabled, freq: $postureFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .posture) })

        WellnessCard(
          title: "Blink",
          subtitle: "Keep your eyes hydrated by blinking.",
          emoji: "👁️", color: .blue, enabled: $blinkEnabled, freq: $blinkFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .blink) })
      }

      HStack(spacing: 20) {
        WellnessCard(
          title: "Drink Water",
          subtitle: "Stay hydrated for better mental focus.",
          emoji: "💧", color: .cyan, enabled: $waterEnabled, freq: $waterFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .water) })

        WellnessCard(
          title: "Affirmations",
          subtitle: "A motivational boost to keep you going.",
          emoji: "⚡️", color: .yellow, enabled: $affirmationEnabled,
          freq: $affirmationFrequency,
          freqOptions: SettingsCatalog.affirmationFrequencyOptions,
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
          ZenRowDivider()
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
          ZenRowDivider()
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
          ZenRowDivider()
          ZenRow(
            title: "Wellness overlay duration",
            subtitle: "Scale reminder visibility across posture, blink, hydration, and affirmations"
          ) {
            ZenDurationMultiplierPicker(multiplier: $wellnessDurationMultiplier)
          }
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Quiet hours")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Pause wellness reminders at night") {
            Toggle("", isOn: $quietHoursEnabled).toggleStyle(.switch).tint(Theme.accent)
          }
          ZenRowDivider()
          ZenRow(title: "Quiet window") {
            HStack(spacing: 8) {
              ZenTimePicker(minuteOfDay: $quietHoursStartMinute)
              Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
              ZenTimePicker(minuteOfDay: $quietHoursEndMinute)
            }
            .opacity(quietHoursEnabled ? 1 : 0.45)
            .allowsHitTesting(quietHoursEnabled)
          }
        }
      }

      Spacer()
    }
  }
}

private struct ZenDurationMultiplierPicker: View {
  @Binding var multiplier: Double

  var body: some View {
    Menu {
      ForEach(SettingsCatalog.wellnessDurationMultiplierOptions, id: \.1) { option in
        Button(option.0) { multiplier = option.1 }
      }
    } label: {
      ZenPickerPill(text: formattedMultiplier)
    }
    .zenMenuStyle()
  }

  private var formattedMultiplier: String {
    "\(String(format: "%.2g", multiplier))x"
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
        RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.16))
        Text(emoji).font(.system(size: 50))
      }.frame(height: 100)

      VStack(spacing: 0) {
        ZenRow(title: "Enabled") { Toggle("", isOn: $enabled).toggleStyle(.switch).tint(color) }
          .padding(.horizontal, -16)
        ZenRowDivider().padding(.horizontal, -16)
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
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.76)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .glassEffect(.regular, in: shape)
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 6)
  }
}
