import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: 16) {
      // Timer Circle
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 3)
        Circle()
          .trim(from: 0, to: CGFloat(stateManager.timeRemaining / 60.0))
          .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .rotationEffect(.degrees(-90))

        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 12, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
      }
      .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text("Break Starting Soon")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
        Text("Your eyes need a 20-second rest.")
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.6))
      }

      Spacer()

      Button("Start Now") {
        stateManager.transition(to: .onBreak)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .tint(.orange)
    }
    .padding(.horizontal, 16)
    .frame(width: 320, height: 70)
    .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let s = Int(max(0, seconds))
    return String(format: "%02d", s)
  }
}
