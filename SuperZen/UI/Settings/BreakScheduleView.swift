import SwiftUI

struct SuperZenBreakScheduleView: View {
  @EnvironmentObject var stateManager: StateManager
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowTyping = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      Text("Break Schedule")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundColor(Theme.textPrimary)

      // Section 1: Timings
      VStack(alignment: .leading, spacing: 12) {
        Text("Timings").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            ZenDurationPicker(
              title: "Work", value: $stateManager.workDuration,
              options: [("10 seconds (Test)", 10), ("20 minutes", 1200), ("45 minutes", 2700)]
            )
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Break duration") {
            ZenDurationPicker(
              title: "Break", value: $stateManager.breakDuration,
              options: [("5 seconds (Test)", 5), ("20 seconds", 20), ("1 minute", 60)]
            )
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Reminder lead time") {
            ZenDurationPicker(
              title: "Reminder lead time",
              value: $stateManager.nudgeLeadTime,
              options: [("10 seconds", 10), ("30 seconds", 30), ("1 minute", 60)]
            )
          }
        }
      }

      // Section 2: Difficulty
      VStack(alignment: .leading, spacing: 12) {
        Text("Break skip difficulty").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary
        )
        HStack(spacing: 14) {
          DifficultyCard(
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: stateManager.difficultyRaw == "Casual"
          ) { stateManager.difficultyRaw = "Casual" }

          DifficultyCard(
            title: "Balanced", subtitle: "Wait 5s to skip", icon: "circle",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: stateManager.difficultyRaw == "Balanced"
          ) { stateManager.difficultyRaw = "Balanced" }

          DifficultyCard(
            title: "Hardcore", subtitle: "No skips allowed", icon: "nosign",
            backgroundGradient: Theme.gradientHardcore,
            isSelected: stateManager.difficultyRaw == "Hardcore"
          ) { stateManager.difficultyRaw = "Hardcore" }
        }
      }

      // Section 3: Rules
      VStack(alignment: .leading, spacing: 12) {
        Text("Rules").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Don't show breaks while I'm typing") {
            Toggle("", isOn: $dontShowTyping).toggleStyle(.switch).tint(.blue)
          }
        }
      }
    }
    .padding(32)
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
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )

        VStack(spacing: 2) {
          Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
          Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
        }
      }
      .frame(maxWidth: .infinity)
      .opacity(isSelected ? 1.0 : 0.6)
    }.buttonStyle(.plain)
  }
}
