import SuperZenCore
import SwiftUI

struct SuperZenBreakScheduleView: View {
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = SettingsCatalog.workDurationDefault
  @AppStorage(SettingKey.breakDuration) private var breakDuration: Double = SettingsCatalog.breakDurationDefault
  @AppStorage(SettingKey.nudgeLeadTime) private var nudgeLeadTime: Double = SettingsCatalog.nudgeLeadTimeDefault
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.dontShowWhileTyping) private var dontShowTyping = true
  @AppStorage(SettingKey.forceResetFocusAfterBreak) private var forceResetFocusAfterBreak = true
  @AppStorage(SettingKey.longBreakDuration) private var longBreakDuration: Double = SettingsCatalog
    .longBreakDurationDefault
  @AppStorage(SettingKey.longBreakEvery) private var longBreakEvery = SettingsCatalog.longBreakEveryDefault
  @AppStorage(SettingKey.typingDeferralCap) private var typingDeferralCap: Double = SettingsCatalog
    .typingDeferralCapDefault

  private var issues: [SettingsIssue] {
    SettingsValidation.issues(in: .standard).filter { $0.section == .breakSchedule }
  }

  var body: some View {
    SettingsPage {
      CardSection("Timings") {
        SettingRow(
          String(localized: "Show breaks after", comment: "Break schedule row title"),
          subtitle: String(
            localized: "of focused screen time", comment: "Break schedule row subtitle")
        ) {
          DurationPicker(
            String(localized: "Work", comment: "Duration picker sheet subject"),
            value: $workDuration,
            options: SettingsCatalog.workDurationOptions,
            minimum: 60)
        }
        CardDivider()
        SettingRow(String(localized: "Break duration", comment: "Break schedule row title")) {
          DurationPicker(
            String(localized: "Break", comment: "Duration picker sheet subject"),
            value: $breakDuration,
            options: SettingsCatalog.breakDurationOptions,
            minimum: 5)
        }
        CardDivider()
        SettingRow(String(localized: "Reminder lead time", comment: "Break schedule row title")) {
          DurationPicker(
            String(localized: "Reminder lead time", comment: "Duration picker sheet subject"),
            value: $nudgeLeadTime,
            options: SettingsCatalog.reminderLeadTimeOptions)
        }
        ForEach(issues, id: \.self) { issue in
          CardDivider()
          ValidationNote(issue.message)
        }
      }

      CardSection(
        "Long breaks",
        subtitle: "A longer rest every few cycles, so your body gets a real reset too."
      ) {
        SettingRow(String(localized: "Take a long break", comment: "Break schedule row title")) {
          MenuPicker(
            String(localized: "Take a long break", comment: "Break schedule row title"),
            selection: $longBreakEvery,
            options: SettingsCatalog.longBreakEveryOptions,
            label: { SettingsCatalog.longBreakEveryDisplayName($0) })
        }
        CardDivider()
        SettingRow(String(localized: "Long break length", comment: "Break schedule row title")) {
          DurationPicker(
            String(localized: "Long break", comment: "Duration picker sheet subject"),
            value: $longBreakDuration,
            options: SettingsCatalog.longBreakOptions(longerThan: breakDuration),
            minimum: SettingsCatalog.longBreakMinimum(longerThan: breakDuration))
        }
        .disabled(longBreakEvery <= 0)
      }

      PageSection("Break skip difficulty") {
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
        SettingRow(
          String(localized: "Wait for typing at most", comment: "Break schedule rule row title"),
          subtitle: String(
            localized: "After this, the break starts even if you are still typing",
            comment: "Break schedule rule row subtitle for the typing cap")
        ) {
          DurationPicker(
            String(localized: "Typing cap", comment: "Duration picker sheet subject"),
            value: $typingDeferralCap,
            options: SettingsCatalog.typingDeferralCapOptions)
        }
        .disabled(!dontShowTyping)
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

      Text(
        "Changes save as you make them. The floating nudge follows your cursor and starts the break when the timer reaches zero."
      )
      .font(ZenFont.bodySmall)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .padding(.horizontal, ZenSpacing.xxs)
    }
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
            .font(ZenFont.labelMedium)
            .foregroundStyle(ZenColor.overlayText)
            .padding(.horizontal, ZenSpacing.sm)
            .padding(.vertical, ZenSpacing.xxs)
            .background(ZenColor.overlayScrim, in: RoundedRectangle(cornerRadius: ZenRadius.xs))
        }
        .frame(height: 80)
        .clipShape(shape)

        VStack(spacing: ZenSpacing.xxs / 2) {
          Text(difficulty.displayName)
            .font(ZenFont.labelMedium)
            .foregroundStyle(ZenColor.onSurface)
          Text(subtitle)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
        }
      }
      .padding(ZenSpacing.sm)
      .frame(maxWidth: .infinity)
      .zenSurface(isSelected: isSelected)
    }
    .buttonStyle(.zenCard)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(difficulty.displayName). \(subtitle)")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
