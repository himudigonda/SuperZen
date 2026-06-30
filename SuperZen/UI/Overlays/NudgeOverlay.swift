import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager
  var isPreview: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      // 1. Sleek Progress Ring
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 3)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(
            stateManager.isTyping ? Color.white.opacity(0.3) : Color.orange,
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        if stateManager.isTyping {
          Image(systemName: "pause.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.6))
        } else {
          Text("\(Int(max(0, ceil(stateManager.timeRemaining))))")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
        }
      }
      .frame(width: 32, height: 32)

      // 2. Compact Text
      VStack(alignment: .leading, spacing: -1) {
        Text("SuperZen")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text(stateManager.isTyping ? "Typing..." : "Rest your eyes")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundColor(.white.opacity(0.5))
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .frame(width: overlayWidth, height: 54)
    .background(
      ZStack {
        if isPreview {
          Color.black.opacity(0.3)
        } else {
          Capsule().fill(Color(white: 0.1).opacity(0.92))
          Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
      }
    )
    .clipShape(Capsule())
    // Passive, cursor-following indicator that never takes focus; the same state is
    // exposed accessibly via the menu bar. Hide it so VoiceOver doesn't announce it
    // repeatedly as the pill tracks the cursor.
    .accessibilityHidden(true)
  }

  private var progress: CGFloat {
    let total = stateManager.nudgeLeadTime > 0 ? stateManager.nudgeLeadTime : 10.0
    let percent = stateManager.timeRemaining / total
    return CGFloat(max(0, min(1, percent)))
  }

  private var overlayWidth: CGFloat {
    isPreview ? 200 : 210
  }
}
