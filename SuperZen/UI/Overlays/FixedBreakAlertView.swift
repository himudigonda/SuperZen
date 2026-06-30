import SwiftUI

struct FixedBreakAlertView: View {
  @EnvironmentObject var stateManager: StateManager
  var isPreview: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {

      // ── Top row: streak badge + close ──────────────────────────────────
      HStack(alignment: .center) {
        HStack(spacing: 5) {
          Image(systemName: "bolt.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color.orange)
          Text("\(Int(stateManager.continuousFocusTime / 60)) mins without a break")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.18))
        .cornerRadius(20)

        Spacer()

        Button(action: { OverlayWindowManager.shared.closeFixedAlert() }) {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white.opacity(0.55))
            .frame(width: 24, height: 24)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 18)
      .padding(.horizontal, 18)

      // ── Timer + message ────────────────────────────────────────────────
      VStack(alignment: .leading, spacing: 4) {
        Text(formatTime(displaySeconds))
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)

        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(.white.opacity(0.55))
          .lineLimit(1)
      }
      .padding(.horizontal, 18)
      .padding(.top, 10)

      Spacer()

      // ── Action buttons ─────────────────────────────────────────────────
      HStack(spacing: 10) {
        Button(action: startNow) {
          Text("Start break now")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
              LinearGradient(
                colors: [
                  Color(red: 0.22, green: 0.56, blue: 1.0),
                  Color(red: 0.14, green: 0.44, blue: 0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)

        if stateManager.difficulty != .hardcore {
          Divider()
            .frame(height: 14)
            .background(Color.white.opacity(0.2))

          Button(action: skipBreak) {
            Text("Skip")
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.white.opacity(0.7))
          }
          .buttonStyle(.plain)
        }

        Button(action: snooze) {
          HStack(spacing: 3) {
            Text("Snooze 5m")
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
          }
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
      }
      .padding(.bottom, 18)
      .padding(.horizontal, 18)
    }
    .frame(width: 420, height: 200)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(red: 0.1, green: 0.1, blue: 0.13).opacity(0.97))
    )
    .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 8)
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
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.snoozeNudge(by: 300)
    }
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
