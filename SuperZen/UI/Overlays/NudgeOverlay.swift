import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: 12) {
      // Animated Progress Circle
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 3)
        Circle()
          .trim(from: 0, to: progressFraction)
          .stroke(
            AngularGradient(colors: [.orange, .yellow, .orange], center: .center),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        Text(String(format: "%.0f", max(0, stateManager.timeRemaining)))
          .font(.system(size: 10, weight: .black, design: .monospaced))
          .foregroundColor(.white)
      }
      .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 0) {
        Text("Break Soon")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.white)
        Text("Rest your eyes")
          .font(.system(size: 9))
          .foregroundColor(.white.opacity(0.6))
      }

      // Minimalist "Start Now" Arrow
      Image(systemName: "arrow.right.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(.orange)
    }
    .padding(.horizontal, 12)
    .frame(width: 180, height: 50)
    .background(VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow))
    .clipShape(Capsule())
    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
  }

  /// Progress fraction clamped to 0...1
  private var progressFraction: CGFloat {
    let leadTime = stateManager.nudgeLeadTime
    guard leadTime > 0 else { return 0 }
    return CGFloat(max(0, min(1, stateManager.timeRemaining / leadTime)))
  }
}
