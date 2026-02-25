import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager
  @State private var canSkip = false
  @State private var skipProgress: Double = 0

  let skipDelay: Double = 5.0  // Wait 5 seconds to allow skip (Balanced Mode)

  var body: some View {
    ZStack {
      // Premium Blur Background
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
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white.opacity(0.5))

        VStack(spacing: 16) {
          Text("Take a moment to breathe")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundColor(.white)

          Text("Enjoy a quick break to relax and recharge!")
            .font(.title2)
            .foregroundColor(.white.opacity(0.8))
        }

        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 120, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
          .contentTransition(.numericText())

        // The Interaction Bar
        HStack(spacing: 20) {
          ZenBreakActionPill(icon: "plus", text: "1 min") {
            stateManager.timeRemaining += 60
          }

          // Skip Button with Internal Progress Ring
          Button(action: { stateManager.transition(to: .active) }) {
            HStack(spacing: 10) {
              if !canSkip {
                ProgressView(value: skipProgress, total: 1.0)
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.6)
                  .frame(width: 15, height: 15)
                Text("Wait for skip")
              } else {
                Image(systemName: "forward.end.fill")
                Text("Skip Break")
              }
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .disabled(!canSkip)

          ZenBreakActionPill(icon: "lock.fill", text: "Lock Screen") {
            lockMacOS()
          }
        }
      }
    }
    .onAppear { startSkipSequence() }
  }

  private func startSkipSequence() {
    // Reset state for new break
    canSkip = false
    skipProgress = 0
    withAnimation(.linear(duration: skipDelay)) { skipProgress = 1.0 }
    DispatchQueue.main.asyncAfter(deadline: .now() + skipDelay) { canSkip = true }
  }

  private func formatTime(_ sec: TimeInterval) -> String {
    let s = Int(max(0, sec))
    return String(format: "00:%02d", s)
  }

  private func lockMacOS() {
    let libHandle = dlopen(
      "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW)
    if let libHandle = libHandle {
      let symbol = dlsym(libHandle, "SACLockScreenImmediate")
      let lock = unsafeBitCast(symbol, to: (@convention(c) () -> Void).self)
      lock()
      dlclose(libHandle)
    }
  }
}

struct ZenBreakActionPill: View {
  let icon: String
  let text: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
        Text(text)
      }
      .font(.system(size: 14, weight: .medium))
      .padding(.horizontal, 24).padding(.vertical, 14)
      .background(Color.white.opacity(0.1))
      .clipShape(Capsule())
    }.buttonStyle(.plain)
  }
}
