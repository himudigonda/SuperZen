import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager
  var isPreview: Bool = false  // Toggle for Settings usage

  var body: some View {
    HStack(spacing: 12) {
      // 1. Sleek Progress Ring
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 3)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(
            Color.orange,
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        Text("\(Int(max(0, stateManager.timeRemaining)))")
          .font(.system(size: 11, weight: .heavy, design: .rounded))
          .foregroundColor(.white)
      }
      .frame(width: 32, height: 32)

      // 2. Compact Text
      VStack(alignment: .leading, spacing: -1) {
        Text("Break Soon")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text("Rest your eyes")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundColor(.white.opacity(0.5))
      }

      Spacer(minLength: 0)

      // 3. Mini Action Button (Hidden in Preview for better looks)
      if !isPreview {
        Button(action: { stateManager.transition(to: .onBreak) }) {
          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .black))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.orange))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .frame(width: isPreview ? 200 : 210, height: 54)  // Substantially smaller
    .background(
      ZStack {
        if isPreview {
          Color.black.opacity(0.3)  // Preview version blends into card
        } else {
          Capsule().fill(Color(white: 0.1).opacity(0.92))
          Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
      }
    )
    .clipShape(Capsule())
  }

  private var progress: CGFloat {
    let total = stateManager.nudgeLeadTime > 0 ? stateManager.nudgeLeadTime : 1.0
    return CGFloat(stateManager.timeRemaining / total)
  }
}
