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
    VStack(alignment: .leading, spacing: ZenSpacing.xl) {
      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: ZenSpacing.lg), GridItem(.flexible())],
        spacing: ZenSpacing.lg
      ) {
        WellnessCard(
          type: .posture,
          title: String(localized: "Posture", comment: "Wellness reminder card title: posture"),
          subtitle: String(
            localized: "Sit up straight and relax your shoulders.",
            comment: "Wellness reminder card subtitle: posture"),
          enabled: $postureEnabled, frequency: $postureFrequency,
          frequencyOptions: SettingsCatalog.commonWellnessFrequencyOptions)
        WellnessCard(
          type: .blink,
          title: String(localized: "Blink", comment: "Wellness reminder card title: blink"),
          subtitle: String(
            localized: "Keep your eyes hydrated by blinking.",
            comment: "Wellness reminder card subtitle: blink"),
          enabled: $blinkEnabled, frequency: $blinkFrequency,
          frequencyOptions: SettingsCatalog.commonWellnessFrequencyOptions)
        WellnessCard(
          type: .water,
          title: String(
            localized: "Drink Water", comment: "Wellness reminder card title: hydration"),
          subtitle: String(
            localized: "Stay hydrated for better mental focus.",
            comment: "Wellness reminder card subtitle: hydration"),
          enabled: $waterEnabled, frequency: $waterFrequency,
          frequencyOptions: SettingsCatalog.commonWellnessFrequencyOptions)
        WellnessCard(
          type: .affirmation,
          title: String(
            localized: "Affirmations", comment: "Wellness reminder card title: affirmations"),
          subtitle: String(
            localized: "A motivational boost to keep you going.",
            comment: "Wellness reminder card subtitle: affirmations"),
          enabled: $affirmationEnabled, frequency: $affirmationFrequency,
          frequencyOptions: SettingsCatalog.affirmationFrequencyOptions)
      }

      CardSection("Common settings") {
        LabeledToggle(
          String(localized: "Dim screen on reminders", comment: "Wellness settings row title"),
          isOn: $dimScreen)
        CardDivider()
        SettingRow(
          String(localized: "Idle cutoff (focus telemetry)", comment: "Wellness settings row title")
        ) {
          DurationPicker(
            String(localized: "Idle cutoff", comment: "Duration picker sheet subject"),
            value: $focusIdleThreshold,
            options: SettingsCatalog.idleThresholdOptions)
        }
        CardDivider()
        SettingRow(
          String(localized: "Interruption threshold", comment: "Wellness settings row title")
        ) {
          DurationPicker(
            String(localized: "Interruption threshold", comment: "Duration picker sheet subject"),
            value: $interruptionThreshold,
            options: SettingsCatalog.interruptionThresholdOptions)
        }
        CardDivider()
        SettingRow(
          String(localized: "Wellness overlay duration", comment: "Wellness settings row title"),
          subtitle: String(
            localized:
              "Scale reminder visibility across posture, blink, hydration, and affirmations",
            comment: "Wellness settings row subtitle for overlay duration")
        ) {
          MenuPicker(
            String(localized: "Wellness overlay duration", comment: "Wellness settings row title"),
            selection: $wellnessDurationMultiplier,
            catalog: SettingsCatalog.wellnessDurationMultiplierOptions)
        }
      }

      CardSection("Quiet hours") {
        LabeledToggle(
          String(
            localized: "Pause wellness reminders at night", comment: "Wellness settings row title"),
          isOn: $quietHoursEnabled)
        CardDivider()
        SettingRow(String(localized: "Quiet window", comment: "Wellness settings row title")) {
          TimeRangePicker(
            start: $quietHoursStartMinute, end: $quietHoursEndMinute, rule: .allowsOvernight)
        }
        .disabled(!quietHoursEnabled)
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

struct WellnessCard: View {
  let type: AppStatus.WellnessType
  let title: String
  let subtitle: String
  @Binding var enabled: Bool
  @Binding var frequency: Double
  let frequencyOptions: [(String, Double)]

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
          Text(title)
            .font(ZenFont.headline)
            .foregroundStyle(ZenColor.textPrimary)
          Text(subtitle)
            .font(ZenFont.caption)
            .foregroundStyle(ZenColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Button {
          OverlayCoordinator.shared.previewWellness(type)
        } label: {
          Image(systemName: "play.circle.fill")
            .font(ZenFont.rowIcon)
            .foregroundStyle(ZenColor.textSecondary)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Preview reminder", comment: "Wellness card preview button"))
        .accessibilityLabel(
          String(localized: "Preview \(title) reminder", comment: "Wellness card preview button"))
      }

      ZStack {
        RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
          .fill(ZenPalette.wellnessTint(type).opacity(0.16))
        Text(ZenPalette.wellnessEmoji(type))
          .font(ZenFont.tileEmoji)
          .accessibilityHidden(true)
      }
      .frame(height: 96)

      VStack(spacing: 0) {
        LabeledToggle(
          String(localized: "Enabled", comment: "Wellness reminder card row title"),
          isOn: $enabled)
        CardDivider()
        SettingRow(String(localized: "Every", comment: "Wellness reminder card row title")) {
          DurationPicker(title, value: $frequency, options: frequencyOptions)
        }
        .disabled(!enabled)
      }
      .padding(.horizontal, -ZenSpacing.md)
    }
    .padding(ZenSpacing.md)
    .zenSurface()
  }
}
