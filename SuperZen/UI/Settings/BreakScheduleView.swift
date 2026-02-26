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
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            ZenDurationPicker(
              title: "Work", value: $workDuration,
              options: SettingsCatalog.workDurationOptions
            )
          }
          ZenRowDivider()

          ZenRow(title: "Break duration") {
            ZenDurationPicker(
              title: "Break", value: $breakDuration,
              options: SettingsCatalog.breakDurationOptions
            )
          }
          ZenRowDivider()

          ZenRow(title: "Reminder lead time") {
            ZenDurationPicker(
              title: "Reminder lead time",
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
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: difficultyRaw == "Casual"
          ) { difficultyRaw = "Casual" }

          DifficultyCard(
            title: "Balanced", subtitle: "Wait 5s to skip", icon: "circle",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: difficultyRaw == "Balanced"
          ) { difficultyRaw = "Balanced" }

          DifficultyCard(
            title: "Hardcore", subtitle: "No skips allowed", icon: "nosign",
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
          ZenRow(title: "Don't show breaks while I'm typing") {
            Toggle("", isOn: $dontShowTyping).toggleStyle(.switch).tint(.blue)
          }
          ZenRowDivider()
          ZenRow(
            title: "Reset focus timer after a completed break",
            subtitle: "Disable to continue from where the work cycle paused"
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
