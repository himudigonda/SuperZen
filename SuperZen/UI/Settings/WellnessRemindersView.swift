import SuperZenCore
import SwiftUI

struct WellnessRemindersView: View {
  @AppStorage(SettingKey.postureEnabled) private var postureEnabled = true
  @AppStorage(SettingKey.postureFrequency) private var postureFrequency: Double = SettingsCatalog
    .postureFrequencyDefault
  @AppStorage(SettingKey.blinkEnabled) private var blinkEnabled = true
  @AppStorage(SettingKey.blinkFrequency) private var blinkFrequency: Double = SettingsCatalog.blinkFrequencyDefault
  @AppStorage(SettingKey.waterEnabled) private var waterEnabled = true
  @AppStorage(SettingKey.waterFrequency) private var waterFrequency: Double = SettingsCatalog
    .longWellnessFrequencyDefault
  @AppStorage(SettingKey.affirmationEnabled) private var affirmationEnabled = true
  @AppStorage(SettingKey.affirmationFrequency) private var affirmationFrequency: Double = SettingsCatalog
    .longWellnessFrequencyDefault
  @AppStorage(SettingKey.focusIdleThreshold) private var focusIdleThreshold: Double = SettingsCatalog
    .idleThresholdDefault
  @AppStorage(SettingKey.interruptionThreshold) private var interruptionThreshold: Double = SettingsCatalog
    .interruptionThresholdDefault
  @AppStorage(SettingKey.dimScreenWellness) private var dimScreen = true
  @AppStorage(SettingKey.quietHoursEnabled) private var quietHoursEnabled = false
  @AppStorage(SettingKey.quietHoursStartMinute) private var quietHoursStartMinute = SettingsCatalog
    .defaultQuietHoursStartMinute
  @AppStorage(SettingKey.quietHoursEndMinute) private var quietHoursEndMinute = SettingsCatalog
    .defaultQuietHoursEndMinute
  @AppStorage(SettingKey.wellnessDurationMultiplier) private var wellnessDurationMultiplier: Double = SettingsCatalog
    .wellnessDurationMultiplierDefault

  var body: some View {
    SettingsPage {
      PageSection("Reminders") {
        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: ZenSpacing.md), GridItem(.flexible())],
          spacing: ZenSpacing.md
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

    }
  }
}

struct WellnessCard: View {
  let type: AppStatus.WellnessType
  let title: String
  let subtitle: String
  @Binding var enabled: Bool
  @Binding var frequency: Double
  let frequencyOptions: [(String, Double)]
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
          Text(title)
            .font(ZenFont.titleMedium)
            .foregroundStyle(ZenColor.onSurface)
          Text(subtitle)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Button {
          OverlayCoordinator.shared.previewWellness(type)
        } label: {
          Image(systemName: "play.circle.fill")
            .font(ZenFont.iconMedium)
            .foregroundStyle(ZenColor.onSurfaceVariant)
        }
        .buttonStyle(.zenIcon)
        .zenTooltip(String(localized: "Preview reminder", comment: "Wellness card preview button"))
        .accessibilityLabel(
          String(localized: "Preview \(title) reminder", comment: "Wellness card preview button"))
      }

      ZStack {
        RoundedRectangle(cornerRadius: ZenRadius.xl, style: .continuous)
          .fill(ZenPalette.wellnessContainer(type, scheme: colorScheme))
        Image(systemName: ZenPalette.wellnessSymbol(type))
          .font(ZenFont.tileEmoji)
          .foregroundStyle(ZenPalette.wellnessOnContainer(type, scheme: colorScheme))
          .accessibilityHidden(true)
      }
      .frame(height: 96)

      VStack(spacing: 0) {
        LabeledToggle(
          String(localized: "Enabled", comment: "Wellness reminder card row title"),
          isOn: $enabled)
        CardDivider()
        SettingRow(String(localized: "Every", comment: "Wellness reminder card row title")) {
          DurationPicker(title, value: $frequency, options: frequencyOptions, minimum: 60)
        }
        .disabled(!enabled)
      }
      .padding(.horizontal, -ZenSpacing.md)
    }
    .padding(ZenSpacing.md)
    .zenSurface()
  }
}
