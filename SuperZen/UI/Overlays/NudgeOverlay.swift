import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(spacing: 16) {
      // Header: The Overtime Nudge
      HStack(spacing: 6) {
        Image(systemName: "bolt.fill")
          .foregroundColor(.orange)
        Text("20 mins without a break")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Color.primary.opacity(0.05))
      .cornerRadius(8)

      // Main Countdown
      Text(formatTime(stateManager.timeRemaining))
        .font(.system(size: 48, weight: .bold, design: .rounded))
        .monospacedDigit()

      Text("Almost time. Your eyes will appreciate a quick rest.")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      // Actions
      HStack(spacing: 12) {
        Button {
          stateManager.transition(to: .onBreak)
        } label: {
          Text("Start this break now")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button {
          stateManager.togglePause()
        } label: {
          Text("Snooze >")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 8)
    }
    .padding(24)
    .frame(width: 320)
    .background(.ultraThinMaterial)
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
    )
    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(max(0, seconds))
    return String(format: "00:%02d", totalSeconds)
  }
}
