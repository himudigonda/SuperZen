import AppKit
import SwiftUI

// simple representable for NSVisualEffectView so we can blur what lies
// behind the borderless overlay window.
struct BlurView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    // nothing to update
  }
}

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager
  @State private var canSkip = false
  @State private var skipProgress: Double = 0

  let skipDelay: Double = 3.0  // 3 seconds for skip to become available

  var body: some View {
    ZStack {
      // Premium blur background: first we draw a translucent visual effect
      // view that actually blurs whatever is behind the borderless window. On
      // top we paint a colourful mesh gradient for style – the opacity lets the
      // real screen blur show through.
      BlurView(material: .underWindowBackground, blendingMode: .behindWindow)
        .ignoresSafeArea()

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
      .opacity(0.4)  // let underlying blur be visible

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

        // FIXED TIMER STRING
        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 120, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
          .contentTransition(.numericText())

        // The Interaction Bar
        HStack(spacing: 20) {
          // FIXED: Now adds 60 full seconds
          ZenBreakActionPill(icon: "plus", text: "1 min") {
            withAnimation {
              stateManager.timeRemaining += 60
            }
          }

          // Skip Button with Internal Progress Ring
          Button(action: { stateManager.transition(to: .active) }) {
            HStack(spacing: 10) {
              if !canSkip {
                // show a system loading icon while waiting for skip
                Image(systemName: "hand.raised.fill")
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

  // FIXED MATH: Correct MM:SS formatting
  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    let mins = total / 60
    let secs = total % 60
    return String(format: "%02d:%02d", mins, secs)
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
