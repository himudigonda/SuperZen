import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    ZStack {
      // The actual UI Card
      VStack(spacing: 16) {
        // Header
        HStack(spacing: 6) {
          Image(systemName: "bolt.fill").foregroundColor(.orange)
          Text("\(Int(stateManager.workDuration / 60)) mins without a break")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)

        // Countdown
        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 48, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
          .monospacedDigit()
          .contentTransition(.numericText())

        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(Theme.textSecondary)
          .multilineTextAlignment(.center)

        // Actions
        HStack(spacing: 12) {
          Button {
            stateManager.transition(to: .onBreak)
          } label: {
            Text("Start this break now")
              .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
              .frame(maxWidth: .infinity).padding(.vertical, 10)
              .background(Color.white.opacity(0.15)).cornerRadius(8)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          Button {
            stateManager.snooze()
          } label: {
            Text("Snooze >")
              .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textSecondary)
              .padding(.horizontal, 12).padding(.vertical, 10)
              .background(Color.white.opacity(0.05)).cornerRadius(8)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        .padding(.top, 8)
      }
      .padding(24)
      .frame(width: 340, height: 220)  // Exact card size
      .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
      .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)  // Smooth drop shadow rendered safely inside the window
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)  // Center the card inside the padded 400x300 NSWindow
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(max(0, seconds))
    let mins = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}
