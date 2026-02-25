import SwiftUI

struct BreakOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  // Balanced: show skip button only after 5 seconds
  @State private var skipVisible = false
  @State private var skipCountdown = 5

  var body: some View {
    ZStack {
      // Background: Deep Mesh Gradient
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.8, 0.2], [1, 0.5],
          // swiftlint:disable:next trailing_comma
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: [
          .black, .indigo.opacity(0.5), .black,
          .purple.opacity(0.3), .blue.opacity(0.4), .black,
          // swiftlint:disable:next trailing_comma
          .black, .indigo.opacity(0.6), .black,
        ]
      )
      .ignoresSafeArea()

      VStack(spacing: 40) {
        // The "Look Away" icon (Closed eyes)
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
            .frame(width: 120, height: 120)

          Text("> <")
            .font(.system(size: 40, weight: .black, design: .rounded))
            .foregroundColor(.white)
        }
        .scaleEffect(
          stateManager.timeRemaining.truncatingRemainder(dividingBy: 4) < 2 ? 1.05 : 1.0
        )
        .animation(.easeInOut(duration: 2).repeatForever(), value: stateManager.timeRemaining)

        VStack(spacing: 12) {
          Text("Look Away")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.white)

          Text("Focus on something 20 feet away")
            .font(.title3)
            .foregroundColor(.white.opacity(0.6))
        }

        // Circular Progress
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.1), lineWidth: 4)
            .frame(width: 80, height: 80)

          Circle()
            .trim(from: 0, to: CGFloat(stateManager.timeRemaining / Double(stateManager.breakSecs)))
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 80, height: 80)
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: stateManager.timeRemaining)
        }

        // Enforcer Skip Button
        enforceSkipView
      }
    }
    .onAppear { setupSkipTimer() }
  }

  // MARK: - Enforcer

  @ViewBuilder
  private var enforceSkipView: some View {
    switch stateManager.difficulty {
    case .casual:
      skipButton

    case .balanced:
      if skipVisible {
        skipButton
          .transition(.opacity.animation(.easeIn))
      } else {
        Text("Skip available in \(skipCountdown)s")
          .font(.caption)
          .foregroundColor(.white.opacity(0.4))
      }

    case .hardcore:
      Label("Hardcore mode — no skips", systemImage: "lock.fill")
        .font(.caption)
        .foregroundColor(.white.opacity(0.4))
    }
  }

  private var skipButton: some View {
    Button {
      stateManager.transition(to: .active)
    } label: {
      Text("Skip Break →")
        .font(.caption)
        .foregroundColor(.white.opacity(0.5))
    }
    .buttonStyle(.plain)
  }

  private func setupSkipTimer() {
    skipVisible = false
    skipCountdown = 5

    guard stateManager.difficulty == .balanced else { return }

    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      if skipCountdown > 1 {
        skipCountdown -= 1
      } else {
        skipVisible = true
        timer.invalidate()
      }
    }
  }
}
