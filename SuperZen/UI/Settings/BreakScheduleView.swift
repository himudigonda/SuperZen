import SwiftUI

struct SuperZenBreakScheduleView: View {
  @AppStorage(SettingKey.workDuration) var workDuration: Double = 1500
  @AppStorage(SettingKey.breakDuration) var breakDuration: Double = 300
  @AppStorage(SettingKey.nudgeLeadTime) var nudgeLeadTime: Double = 10
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowTyping = true
  @AppStorage(SettingKey.forceResetFocusAfterBreak) var forceResetFocusAfterBreak = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      Text("Break Schedule")
        .font(.title2.weight(.bold))
        .foregroundColor(Theme.textPrimary)

      VStack(alignment: .leading, spacing: 12) {
        Text("Timings")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(
            title: String(localized: "Show breaks after", comment: "Break schedule row title"),
            subtitle: String(
              localized: "of focused screen time", comment: "Break schedule row subtitle")
          ) {
            ZenDurationPicker(
              title: String(localized: "Work", comment: "Duration picker sheet subject"),
              value: $workDuration,
              options: SettingsCatalog.workDurationOptions
            )
          }
          ZenRowDivider()

          ZenRow(title: String(localized: "Break duration", comment: "Break schedule row title")) {
            ZenDurationPicker(
              title: String(localized: "Break", comment: "Duration picker sheet subject"),
              value: $breakDuration,
              options: SettingsCatalog.breakDurationOptions
            )
          }
          ZenRowDivider()

          ZenRow(
            title: String(localized: "Reminder lead time", comment: "Break schedule row title")
          ) {
            ZenDurationPicker(
              title: String(
                localized: "Reminder lead time", comment: "Duration picker sheet subject"),
              value: $nudgeLeadTime,
              options: SettingsCatalog.reminderLeadTimeOptions
            )
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Break skip difficulty")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        HStack(spacing: 14) {
          DifficultyCard(
            title: BreakDifficulty.casual.displayName,
            subtitle: String(
              localized: "Skip anytime", comment: "Break skip difficulty subtitle: casual"),
            icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: difficultyRaw == "Casual"
          ) { difficultyRaw = "Casual" }

          DifficultyCard(
            title: BreakDifficulty.balanced.displayName,
            subtitle: String(
              localized: "Wait, then skip", comment: "Break skip difficulty subtitle: balanced"),
            icon: "lock.open.fill",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: difficultyRaw == "Balanced"
          ) { difficultyRaw = "Balanced" }

          DifficultyCard(
            title: BreakDifficulty.hardcore.displayName,
            subtitle: String(
              localized: "No skips allowed", comment: "Break skip difficulty subtitle: hardcore"),
            icon: "nosign",
            backgroundGradient: Theme.gradientHardcore,
            isSelected: difficultyRaw == "Hardcore"
          ) { difficultyRaw = "Hardcore" }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Rules")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(
            title: String(
              localized: "Don't show breaks while I'm typing",
              comment: "Break schedule rule row title")
          ) {
            Toggle("", isOn: $dontShowTyping).toggleStyle(.switch).tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: String(
              localized: "Reset focus timer after a completed break",
              comment: "Break schedule rule row title"
            ),
            subtitle: String(
              localized: "Disable to continue from where the work cycle paused",
              comment: "Break schedule rule row subtitle")
          ) {
            Toggle("", isOn: $forceResetFocusAfterBreak).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      Text("Floating nudge follows your cursor and auto-starts break when the timer reaches zero.")
        .font(.caption.weight(.medium))
        .foregroundColor(Theme.textSecondary)
    }
  }
}

struct DifficultyCard: View {
  let title: String
  let subtitle: String
  let icon: String
  let backgroundGradient: LinearGradient
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    Button(action: action) {
      VStack(spacing: 12) {
        ZStack {
          backgroundGradient
          HStack(spacing: 8) {
            Image(systemName: icon)
            Text(isSelected ? "Selected" : "Select")
          }
          .font(.system(size: 11, weight: .black))
          .foregroundColor(.white)
          .padding(.horizontal, 10).padding(.vertical, 4)
          .background(.black.opacity(0.2))
          .cornerRadius(6)
        }
        .frame(height: 80)
        .clipShape(shape)
        .overlay(shape.stroke(isSelected ? Theme.accent : .clear, lineWidth: 2))

        VStack(spacing: 2) {
          Text(title).font(.subheadline.weight(.bold)).foregroundColor(Theme.textPrimary)
          Text(subtitle).font(.caption).foregroundColor(Theme.textSecondary)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity)
      .background {
        shape.fill(.thinMaterial)
        shape.fill(
          LinearGradient(
            colors: [Theme.surfaceTintTop.opacity(0.88), Theme.surfaceTintBottom.opacity(0.74)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      }
      .glassEffect(.regular, in: shape)
      .overlay(
        shape.stroke(
          isSelected ? Theme.accent.opacity(0.95) : Theme.surfaceStroke,
          lineWidth: isSelected ? 2 : 1)
      )
      .shadow(color: Theme.cardShadow.opacity(isSelected ? 1.0 : 0.65), radius: 14, x: 0, y: 5)
      .opacity(isSelected ? 1.0 : 0.95)
    }.buttonStyle(.plain)
  }
}
