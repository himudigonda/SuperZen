import SwiftUI

struct FixedBreakAlertView: View {
  @EnvironmentObject var stateManager: StateManager
  var isPreview: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        HStack(spacing: 6) {
          Image(systemName: "bolt.fill")
          Text("\(focusMinutes) mins without a break")
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)

        Spacer()

        Button(action: { OverlayWindowManager.shared.closeFixedAlert() }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(.white.opacity(0.35))
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 16)
      .padding(.horizontal, 16)

      VStack(alignment: .leading, spacing: 3) {
        Text(formatTime(displaySeconds))
          .font(.system(size: 52, weight: .bold, design: .rounded))
          .monospacedDigit()
        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)

      Spacer()

      HStack(spacing: 14) {
        Button(action: startNow) {
          Text("Start this break now")
            .font(.system(size: 15, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(22)
        }
        .buttonStyle(.plain)

        Button(action: skipBreak) {
          Text("Skip break")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white.opacity(0.8))
        }.buttonStyle(.plain)

        Button(action: snooze) {
          HStack(spacing: 4) {
            Text("Snooze")
            Image(systemName: "chevron.right")
          }
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white.opacity(0.65))
        }
        .buttonStyle(.plain)
      }
      .padding(.bottom, 16)
      .padding(.horizontal, 16)
    }
    .frame(width: 440, height: 220)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: 24).fill(Color(white: 0.12).opacity(0.96))
        RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1)
      }
    )
  }

  private var focusMinutes: Int {
    Int(TelemetryService.shared.getFocusTimeSinceLastCompletedBreak() / 60)
  }

  private var displaySeconds: TimeInterval {
    isPreview ? stateManager.nudgeLeadTime : stateManager.timeRemaining
  }

  private func startNow() {
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.transition(to: .onBreak)
    }
  }

  private func snooze() {
    OverlayWindowManager.shared.closeFixedAlert()
  }

  private func skipBreak() {
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.transition(to: .active)
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
