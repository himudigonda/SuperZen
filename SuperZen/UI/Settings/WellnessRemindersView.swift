import SuperZenCore
import SwiftUI

struct WellnessRemindersView: View {
  @State private var postureEnabled = true
  @State private var postureFrequency: Double = SettingsCatalog.shortWellnessFrequencyDefault
  @State private var blinkEnabled = true
  @State private var blinkFrequency: Double = SettingsCatalog.shortWellnessFrequencyDefault
  @State private var waterEnabled = true
  @State private var waterFrequency: Double = SettingsCatalog.longWellnessFrequencyDefault
  @State private var affirmationEnabled = true
  @State private var affirmationFrequency: Double = SettingsCatalog.longWellnessFrequencyDefault
  @State private var focusIdleThreshold: Double = SettingsCatalog.idleThresholdDefault
  @State private var interruptionThreshold: Double = SettingsCatalog.interruptionThresholdDefault
  @State private var dimScreen = true
  @State private var quietHoursEnabled = false
  @State private var quietHoursStartMinute = SettingsCatalog.defaultQuietHoursStartMinute
  @State private var quietHoursEndMinute = SettingsCatalog.defaultQuietHoursEndMinute
  @State private var wellnessDurationMultiplier: Double = SettingsCatalog
    .wellnessDurationMultiplierDefault

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
          onPreview: { OverlayCoordinator.shared.previewWellness(.posture) })

        WellnessCard(
          title: String(localized: "Blink", comment: "Wellness reminder card title: blink"),
          subtitle: String(
            localized: "Keep your eyes hydrated by blinking.",
            comment: "Wellness reminder card subtitle: blink"),
          emoji: "👁️", color: .blue, enabled: $blinkEnabled, freq: $blinkFrequency,
          freqOptions: SettingsCatalog.commonWellnessFrequencyOptions,
          onPreview: { OverlayCoordinator.shared.previewWellness(.blink) })
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
          onPreview: { OverlayCoordinator.shared.previewWellness(.water) })

        WellnessCard(
          title: String(
            localized: "Affirmations", comment: "Wellness reminder card title: affirmations"),
          subtitle: String(
            localized: "A motivational boost to keep you going.",
            comment: "Wellness reminder card subtitle: affirmations"),
          emoji: "⚡️", color: .yellow, enabled: $affirmationEnabled,
          freq: $affirmationFrequency,
          freqOptions: SettingsCatalog.affirmationFrequencyOptions,
          onPreview: { OverlayCoordinator.shared.previewWellness(.affirmation) })
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
              options: SettingsCatalog.idleThresholdOptions
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
              options: SettingsCatalog.interruptionThresholdOptions
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

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  private func load() {
    let d = UserDefaults.standard
    postureEnabled = d.bool(forKey: SettingKey.postureEnabled)
    postureFrequency = d.double(forKey: SettingKey.postureFrequency)
    blinkEnabled = d.bool(forKey: SettingKey.blinkEnabled)
    blinkFrequency = d.double(forKey: SettingKey.blinkFrequency)
    waterEnabled = d.bool(forKey: SettingKey.waterEnabled)
    waterFrequency = d.double(forKey: SettingKey.waterFrequency)
    affirmationEnabled = d.bool(forKey: SettingKey.affirmationEnabled)
    affirmationFrequency = d.double(forKey: SettingKey.affirmationFrequency)
    focusIdleThreshold = d.double(forKey: SettingKey.focusIdleThreshold)
    interruptionThreshold = d.double(forKey: SettingKey.interruptionThreshold)
    dimScreen = d.bool(forKey: SettingKey.dimScreenWellness)
    quietHoursEnabled = d.bool(forKey: SettingKey.quietHoursEnabled)
    quietHoursStartMinute = d.integer(forKey: SettingKey.quietHoursStartMinute)
    quietHoursEndMinute = d.integer(forKey: SettingKey.quietHoursEndMinute)
    wellnessDurationMultiplier = d.double(forKey: SettingKey.wellnessDurationMultiplier)
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(postureEnabled, forKey: SettingKey.postureEnabled)
    d.set(postureFrequency, forKey: SettingKey.postureFrequency)
    d.set(blinkEnabled, forKey: SettingKey.blinkEnabled)
    d.set(blinkFrequency, forKey: SettingKey.blinkFrequency)
    d.set(waterEnabled, forKey: SettingKey.waterEnabled)
    d.set(waterFrequency, forKey: SettingKey.waterFrequency)
    d.set(affirmationEnabled, forKey: SettingKey.affirmationEnabled)
    d.set(affirmationFrequency, forKey: SettingKey.affirmationFrequency)
    d.set(focusIdleThreshold, forKey: SettingKey.focusIdleThreshold)
    d.set(interruptionThreshold, forKey: SettingKey.interruptionThreshold)
    d.set(dimScreen, forKey: SettingKey.dimScreenWellness)
    d.set(quietHoursEnabled, forKey: SettingKey.quietHoursEnabled)
    d.set(quietHoursStartMinute, forKey: SettingKey.quietHoursStartMinute)
    d.set(quietHoursEndMinute, forKey: SettingKey.quietHoursEndMinute)
    d.set(wellnessDurationMultiplier, forKey: SettingKey.wellnessDurationMultiplier)
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
