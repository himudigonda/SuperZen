import SwiftUI

struct LookAwayBreakScheduleView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("General").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            ZenDurationPicker(
              title: "Work", value: $stateManager.workDuration,
              // swiftlint:disable trailing_comma
              options: [
                ("10 seconds (Test)", 10),
                ("20 minutes", 1200),
                ("45 minutes", 2700),
              ])
            // swiftlint:enable trailing_comma
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Break duration") {
            ZenDurationPicker(
              title: "Break", value: $stateManager.breakDuration,
              // swiftlint:disable trailing_comma
              options: [
                ("4 seconds (Test)", 4),
                ("20 seconds", 20),
                ("1 minute", 60),
              ])
            // swiftlint:enable trailing_comma
          }
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Break skip difficulty").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)
        HStack(spacing: 14) {
          DifficultyCard(
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: stateManager.difficultyRaw == "Casual"
          ) { stateManager.difficultyRaw = "Casual" }
          DifficultyCard(
            title: "Balanced", subtitle: "Skip after a pause", icon: "circle",
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
    Button(
      action: action,
      label: {
        VStack(spacing: 12) {
          ZStack {
            backgroundGradient
            HStack {
              Image(systemName: icon)
              Text("Skip Break")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white.opacity(0.9))
          }
          .frame(height: 80)
          .cornerRadius(10)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
          )

          VStack(spacing: 4) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textPrimary)
            Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
          }
        }
      }
    )
    .buttonStyle(.plain)
  }
}
