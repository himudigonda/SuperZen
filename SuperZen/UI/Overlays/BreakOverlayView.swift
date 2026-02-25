import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    ZStack {
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.8, 0.2], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: [
          .black, .indigo.opacity(0.8), .black,
          .orange.opacity(0.3), .blue.opacity(0.6), .black,
          .black, .purple.opacity(0.7), .black,
        ]
      )
      .ignoresSafeArea()
      .blur(radius: 60)

      VStack(spacing: 50) {
        Text("Current time is \(Date().formatted(date: .omitted, time: .shortened))")
          .foregroundColor(.white.opacity(0.5))

        VStack(spacing: 16) {
          Text("Take a moment to breathe")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

          Text("Enjoy a quick break to relax and recharge!")
            .font(.title2)
            .foregroundColor(.white.opacity(0.8))
        }

        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 100, weight: .bold, design: .monospaced))
          .foregroundColor(.white)

        HStack(spacing: 24) {
          Button(action: { stateManager.transition(to: .active) }) {
            HStack {
              Image(systemName: "forward.end.fill")
              Text("Skip Break")
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          Button(action: {}) {
            Label("Lock Screen", systemImage: "lock.fill")
              .padding(.horizontal, 32).padding(.vertical, 16)
              .background(Color.white.opacity(0.1))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func formatTime(_ sec: TimeInterval) -> String {
    // swiftlint:disable:next identifier_name
    // variable name intentionally short; renaming breaks dependent animation logic
    let s = Int(max(0, sec))
    return String(format: "00:%02d", s)
  }
}
