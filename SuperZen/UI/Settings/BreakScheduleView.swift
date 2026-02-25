import SwiftUI

struct LookAwayBreakScheduleView: View {
  @EnvironmentObject var stateManager: StateManager

  @State private var showingCustomWork = false
  @State private var customWorkInput = ""

  @State private var showingCustomBreak = false
  @State private var customBreakInput = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // SECTION: General
      VStack(alignment: .leading, spacing: 12) {
        Text("General").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)

        ZenCard {
          // Row 1: Show breaks after
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            Menu {
              Button("10 seconds (Test)") { stateManager.workDuration = 10 }
              Button("20 minutes") { stateManager.workDuration = 1200 }
              Button("30 minutes") { stateManager.workDuration = 1800 }
              Divider()
              Button("Custom...") { showingCustomWork = true }
            } label: {
              CustomPill(text: formatDurationLabel(stateManager.workDuration))
            }
            .menuStyle(.borderlessButton)
          }

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          // Row 2: Break duration
          ZenRow(title: "Break duration") {
            Menu {
              Button("4 seconds (Test)") { stateManager.breakDuration = 4 }
              Button("20 seconds") { stateManager.breakDuration = 20 }
              Button("1 minute") { stateManager.breakDuration = 60 }
              Divider()
              Button("Custom...") { showingCustomBreak = true }
            } label: {
              CustomPill(text: formatDurationLabel(stateManager.breakDuration))
            }
            .menuStyle(.borderlessButton)
          }

          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          // Row 3: Typing Toggle
          ZenRow(title: "Don't show breaks while I'm typing or dragging") {
            Toggle("", isOn: $stateManager.dontShowWhileTyping)
              .toggleStyle(.switch)
              .tint(.blue)
          }
        }
      }

      // SECTION: Break Skip Difficulty (Pixel Perfect Cards)
      VStack(alignment: .leading, spacing: 12) {
        Text("Break skip difficulty").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)

        HStack(spacing: 14) {
          DifficultyCard(
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: stateManager.difficultyRaw == "Casual"
          ) {
            stateManager.difficultyRaw = "Casual"
          }

          DifficultyCard(
            title: "Balanced", subtitle: "Skip after a pause", icon: "circle",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: stateManager.difficultyRaw == "Balanced"
          ) {
            stateManager.difficultyRaw = "Balanced"
          }

          DifficultyCard(
            title: "Hardcore", subtitle: "No skips allowed", icon: "nosign",
            backgroundGradient: Theme.gradientHardcore,
            isSelected: stateManager.difficultyRaw == "Hardcore"
          ) {
            stateManager.difficultyRaw = "Hardcore"
          }
        }
      }
    }
    // Custom Input Dialogs
    .alert("Custom Work Duration", isPresented: $showingCustomWork) {
      TextField("Minutes", text: $customWorkInput)
      Button("OK") {
        if let minutes = Double(customWorkInput) { stateManager.workDuration = minutes * 60 }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Enter minutes of focus time.")
    }

    .alert("Custom Break Duration", isPresented: $showingCustomBreak) {
      TextField("Seconds", text: $customBreakInput)
      Button("OK") {
        if let seconds = Double(customBreakInput) { stateManager.breakDuration = seconds }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Enter seconds for the break.")
    }
  }

  private func formatDurationLabel(_ seconds: Double) -> String {
    if seconds < 60 { return "\(Int(seconds)) seconds" }
    return "\(Int(seconds / 60)) minute\(seconds == 60 ? "" : "s")"
  }
}

// MARK: - Reusable UI Elements

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
    .background(Color.black.opacity(0.4))
    .cornerRadius(6)
    .foregroundColor(Theme.textPrimary)
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
