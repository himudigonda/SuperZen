import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: 14) {
      // 1. Circular Progress with Countdown
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 4)
        Circle()
          .trim(from: 0, to: CGFloat(stateManager.timeRemaining / stateManager.nudgeLeadTime))
          .stroke(
            Color.orange,
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        Text("\(Int(max(0, stateManager.timeRemaining)))")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
      .frame(width: 42, height: 42)

      // 2. Text Content
      VStack(alignment: .leading, spacing: 0) {
        Text("Break Soon")
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text("Rest your eyes")
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundColor(.white.opacity(0.5))
      }

      Spacer(minLength: 0)

      // 3. Action Button
      Button(action: { stateManager.transition(to: .onBreak) }) {
        Image(systemName: "arrow.right")
          .font(.system(size: 18, weight: .black))
          .foregroundColor(.white)
          .frame(width: 40, height: 40)
          .background(Circle().fill(Color.orange))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .frame(width: 240, height: 70)
    .background(
      ZStack {
        // The signature dark frosted pill
        RoundedRectangle(cornerRadius: 35)
          .fill(Color(white: 0.12).opacity(0.95))
        RoundedRectangle(cornerRadius: 35)
          .stroke(Color.white.opacity(0.1), lineWidth: 1)
      }
    )
    // Clip to pill shape
    .clipShape(Capsule())
  }
}
