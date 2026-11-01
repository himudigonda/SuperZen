import SuperZenCore
import SwiftUI

struct SuperZenBreakScheduleView: View {
  @State private var workDuration: Double = SettingsCatalog.workDurationDefault
  @State private var breakDuration: Double = SettingsCatalog.breakDurationDefault
  @State private var nudgeLeadTime: Double = SettingsCatalog.nudgeLeadTimeDefault
  @State private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @State private var dontShowTyping = true
  @State private var forceResetFocusAfterBreak = true

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      Text("Break Schedule")
        .font(ZenFont.title)
        .foregroundStyle(ZenColor.textPrimary)
        .accessibilityAddTraits(.isHeader)

      CardSection("Timings") {
        SettingRow(
          String(localized: "Show breaks after", comment: "Break schedule row title"),
          subtitle: String(
            localized: "of focused screen time", comment: "Break schedule row subtitle")
        ) {
          DurationPicker(
            String(localized: "Work", comment: "Duration picker sheet subject"),
            value: $workDuration,
            options: SettingsCatalog.workDurationOptions)
        }
        CardDivider()
        SettingRow(String(localized: "Break duration", comment: "Break schedule row title")) {
          DurationPicker(
            String(localized: "Break", comment: "Duration picker sheet subject"),
            value: $breakDuration,
            options: SettingsCatalog.breakDurationOptions)
        }
        CardDivider()
        SettingRow(String(localized: "Reminder lead time", comment: "Break schedule row title")) {
          DurationPicker(
            String(localized: "Reminder lead time", comment: "Duration picker sheet subject"),
            value: $nudgeLeadTime,
            options: SettingsCatalog.reminderLeadTimeOptions)
        }
      }

      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        SectionHeader("Break skip difficulty")
        HStack(spacing: ZenSpacing.md) {
          ForEach(BreakDifficulty.allCases) { difficulty in
            DifficultyCard(
              difficulty: difficulty,
              subtitle: subtitle(for: difficulty),
              icon: icon(for: difficulty),
              isSelected: difficultyRaw == difficulty.rawValue
            ) { difficultyRaw = difficulty.rawValue }
          }
        }
      }

      CardSection("Rules") {
        LabeledToggle(
          String(
            localized: "Don't show breaks while I'm typing", comment: "Break schedule rule row title"),
          isOn: $dontShowTyping)
        CardDivider()
        LabeledToggle(
          String(
            localized: "Reset focus timer after a completed break",
            comment: "Break schedule rule row title"),
          subtitle: String(
            localized: "Disable to continue from where the work cycle paused",
            comment: "Break schedule rule row subtitle"),
          isOn: $forceResetFocusAfterBreak)
      }

      Text("Floating nudge follows your cursor and auto-starts break when the timer reaches zero.")
        .font(ZenFont.subheadline)
        .foregroundStyle(ZenColor.textSecondary)

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  private func subtitle(for difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual:
      return String(localized: "Skip anytime", comment: "Break skip difficulty subtitle: casual")
    case .balanced:
      return String(
        localized: "Wait, then skip", comment: "Break skip difficulty subtitle: balanced")
    case .hardcore:
      return String(
        localized: "No skips allowed", comment: "Break skip difficulty subtitle: hardcore")
    }
  }

  private func icon(for difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual: return "forward.end.fill"
    case .balanced: return "lock.open.fill"
    case .hardcore: return "nosign"
    }
  }

  private func load() {
    let d = UserDefaults.standard
    workDuration = d.double(forKey: SettingKey.workDuration)
    breakDuration = d.double(forKey: SettingKey.breakDuration)
    nudgeLeadTime = d.double(forKey: SettingKey.nudgeLeadTime)
    difficultyRaw = d.string(forKey: SettingKey.difficulty) ?? BreakDifficulty.balanced.rawValue
    dontShowTyping = d.bool(forKey: SettingKey.dontShowWhileTyping)
    forceResetFocusAfterBreak = d.bool(forKey: SettingKey.forceResetFocusAfterBreak)
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(workDuration, forKey: SettingKey.workDuration)
    d.set(breakDuration, forKey: SettingKey.breakDuration)
    d.set(nudgeLeadTime, forKey: SettingKey.nudgeLeadTime)
    d.set(difficultyRaw, forKey: SettingKey.difficulty)
    d.set(dontShowTyping, forKey: SettingKey.dontShowWhileTyping)
    d.set(forceResetFocusAfterBreak, forKey: SettingKey.forceResetFocusAfterBreak)
  }
}

struct DifficultyCard: View {
  let difficulty: BreakDifficulty
  let subtitle: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      VStack(spacing: ZenSpacing.sm) {
        ZStack {
          ZenPalette.difficultyGradient(difficulty)
          Label(isSelected ? "Selected" : "Select", systemImage: icon)
            .font(ZenFont.captionEmphasized)
            .foregroundStyle(ZenColor.overlayText)
            .padding(.horizontal, ZenSpacing.sm)
            .padding(.vertical, ZenSpacing.xxs)
            .background(ZenColor.overlayScrim, in: RoundedRectangle(cornerRadius: ZenRadius.xs))
        }
        .frame(height: 80)
        .clipShape(shape)

        VStack(spacing: ZenSpacing.xxs / 2) {
          Text(difficulty.displayName)
            .font(ZenFont.subheadlineEmphasized)
            .foregroundStyle(ZenColor.textPrimary)
          Text(subtitle)
            .font(ZenFont.caption)
            .foregroundStyle(ZenColor.textSecondary)
        }
      }
      .padding(ZenSpacing.sm)
      .frame(maxWidth: .infinity)
      .zenSurface(isSelected: isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(difficulty.displayName). \(subtitle)")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
