import SwiftUI

struct SuperZenBreakScheduleView: View {
  @State private var workDuration: Double = SettingsCatalog.workDurationDefault
  @State private var breakDuration: Double = SettingsCatalog.breakDurationDefault
  @State private var nudgeLeadTime: Double = SettingsCatalog.nudgeLeadTimeDefault
  @State private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @State private var dontShowTyping = true
  @State private var forceResetFocusAfterBreak = true

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
            isSelected: difficultyRaw == BreakDifficulty.casual.rawValue
          ) { difficultyRaw = BreakDifficulty.casual.rawValue }

          DifficultyCard(
            title: BreakDifficulty.balanced.displayName,
            subtitle: String(
              localized: "Wait, then skip", comment: "Break skip difficulty subtitle: balanced"),
            icon: "lock.open.fill",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: difficultyRaw == BreakDifficulty.balanced.rawValue
          ) { difficultyRaw = BreakDifficulty.balanced.rawValue }

          DifficultyCard(
            title: BreakDifficulty.hardcore.displayName,
            subtitle: String(
              localized: "No skips allowed", comment: "Break skip difficulty subtitle: hardcore"),
            icon: "nosign",
            backgroundGradient: Theme.gradientHardcore,
            isSelected: difficultyRaw == BreakDifficulty.hardcore.rawValue
          ) { difficultyRaw = BreakDifficulty.hardcore.rawValue }
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

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
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
