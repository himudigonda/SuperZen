import SwiftUI

struct WellnessRemindersView: View {
  @AppStorage(SettingKey.postureEnabled) var postureEnabled = true
  @AppStorage(SettingKey.postureFrequency) var postureFrequency: Double = 1200
  @AppStorage(SettingKey.blinkEnabled) var blinkEnabled = true
  @AppStorage(SettingKey.blinkFrequency) var blinkFrequency: Double = 1200
  @AppStorage(SettingKey.waterEnabled) var waterEnabled = true
  @AppStorage(SettingKey.waterFrequency) var waterFrequency: Double = 3600
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
          title: String(localized: "Posture", comment: "Wellness reminder card title: posture"),
          subtitle: String(
            localized: "Sit up straight and relax your shoulders.",
            comment: "Wellness reminder card subtitle: posture"),
          emoji: "🧘‍♂️", color: .pink, enabled: $postureEnabled, freq: $postureFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .posture) })

        WellnessCard(
          title: String(localized: "Blink", comment: "Wellness reminder card title: blink"),
          subtitle: String(
            localized: "Keep your eyes hydrated by blinking.",
            comment: "Wellness reminder card subtitle: blink"),
          emoji: "👁️", color: .blue, enabled: $blinkEnabled, freq: $blinkFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .blink) })
      }

      HStack(spacing: 20) {
        WellnessCard(
          title: String(
            localized: "Drink Water", comment: "Wellness reminder card title: hydration"),
          subtitle: String(
            localized: "Stay hydrated for better mental focus.",
            comment: "Wellness reminder card subtitle: hydration"),
          emoji: "💧", color: .cyan, enabled: $waterEnabled, freq: $waterFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { WellnessManager.shared.triggerPreview(type: .water) })

        WellnessCard(
          title: String(
            localized: "Affirmations", comment: "Wellness reminder card title: affirmations"),
          subtitle: String(
            localized: "A motivational boost to keep you going.",
            comment: "Wellness reminder card subtitle: affirmations"),
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
          ZenRow(
            title: String(
              localized: "Dim screen on reminders", comment: "Wellness settings row title")
          ) {
            Toggle("", isOn: $dimScreen).toggleStyle(.switch).tint(Theme.accent)
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Idle cutoff (focus telemetry)", comment: "Wellness settings row title")
          ) {
            ZenDurationPicker(
              title: String(localized: "Idle cutoff", comment: "Duration picker sheet subject"),
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
          ZenRow(
            title: String(
              localized: "Interruption threshold", comment: "Wellness settings row title")
          ) {
            ZenDurationPicker(
              title: String(
                localized: "Interruption threshold", comment: "Duration picker sheet subject"),
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
            title: String(
              localized: "Wellness overlay duration", comment: "Wellness settings row title"),
            subtitle: String(
              localized:
                "Scale reminder visibility across posture, blink, hydration, and affirmations",
              comment: "Wellness settings row subtitle for overlay duration")
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
          ZenRow(
            title: String(
              localized: "Pause wellness reminders at night", comment: "Wellness settings row title"
            )
          ) {
            Toggle("", isOn: $quietHoursEnabled).toggleStyle(.switch).tint(Theme.accent)
          }
          ZenRowDivider()
          ZenRow(title: String(localized: "Quiet window", comment: "Wellness settings row title")) {
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
    // Reverse-map to the catalog label so the pill matches the menu exactly
    // (e.g. "1.0x", not "%.2g" → "1x").
    SettingsCatalog.wellnessDurationMultiplierOptions.first { $0.1 == multiplier }?.0
      ?? "\(String(format: "%.2g", multiplier))x"
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
        ZenRow(title: String(localized: "Enabled", comment: "Wellness reminder card row title")) {
          Toggle("", isOn: $enabled).toggleStyle(.switch).tint(color)
        }
        .padding(.horizontal, -16)
        ZenRowDivider().padding(.horizontal, -16)
        ZenRow(title: String(localized: "Every", comment: "Wellness reminder card row title")) {
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
