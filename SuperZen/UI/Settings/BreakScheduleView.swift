import SwiftUI

// MARK: - Pixel-Perfect "Break Schedule" View

struct LookAwayBreakScheduleView: View {
  @AppStorage(SettingKey.workDuration) var workMins = 20
  @AppStorage(SettingKey.breakDuration) var breakSecs = 60
  @AppStorage(SettingKey.difficulty) var difficultyRaw = BreakDifficulty.balanced.rawValue
  @State private var dontShowTyping = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // SECTION: General
      VStack(alignment: .leading, spacing: 10) {
        Text("General").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)

        ZenCard {
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            CustomPill(text: "\(workMins) minutes")
          }
          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Break duration", subtitle: nil) {
            CustomPill(text: "\(breakSecs / 60) minute")
          }
          Divider().background(Color.white.opacity(0.05))

          ZenRow(title: "Don't show breaks while I'm typing or dragging") {
            Toggle("", isOn: $dontShowTyping).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      // SECTION: Break Skip Difficulty
      VStack(alignment: .leading, spacing: 10) {
        Text("Break skip difficulty").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)

        HStack(spacing: 16) {
          DifficultyCard(
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual, isSelected: difficultyRaw == "Casual"
          ) {
            difficultyRaw = "Casual"
          }

          DifficultyCard(
            title: "Balanced", subtitle: "Skip after a pause", icon: "circle",
            backgroundGradient: Theme.gradientBalanced, isSelected: difficultyRaw == "Balanced"
          ) {
            difficultyRaw = "Balanced"
          }

          DifficultyCard(
            title: "Hardcore", subtitle: "No skips allowed", icon: "nosign",
            backgroundGradient: Theme.gradientHardcore, isSelected: difficultyRaw == "Hardcore"
          ) {
            difficultyRaw = "Hardcore"
          }
        }
      }
    }
  }
}

// MARK: - Reusable UI Elements

// The dark gray pills with up/down chevrons
struct CustomPill: View {
  let text: String
  var body: some View {
    HStack(spacing: 8) {
      Text(text)
        .font(.system(size: 13))
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 10))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.4))  // Dark pill background
    .cornerRadius(6)
    .foregroundColor(Theme.textPrimary)
  }
}

// The Gradient Cards
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
