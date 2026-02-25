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

  var body: some View {
    ZStack {
      // Premium blur background: first we draw a translucent visual effect
      // view that actually blurs whatever is behind the borderless window.
      BlurView(material: .underWindowBackground, blendingMode: .behindWindow)
        .ignoresSafeArea()

      // Background Gradient Overlay
      if #available(macOS 15.0, *) {
        MeshGradient(
          width: 3, height: 3,
          points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.8, 0.2], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
          ],
          colors: [
            .black, Color(hex: "1A237E"), .black,
            Color(hex: "4A148C"), Color(hex: "01579B"), .black,
            .black, Color(hex: "311B92"), .black,
          ]
        )
        .ignoresSafeArea()
        .opacity(0.4)  // let underlying blur be visible
      } else {
        LinearGradient(
          colors: [.black, Color(hex: "1A237E"), .black],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .opacity(0.6)
      }

      VStack(spacing: 50) {
        Text("Current time is \(Date().formatted(date: .omitted, time: .shortened))")
          .foregroundColor(.white.opacity(0.5))

        VStack(spacing: 16) {
          Text("Take a moment to breathe")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundColor(.white)
          Text("Enjoy a quick break to relax and recharge!")
            .font(.title2)
            .foregroundColor(.white.opacity(0.8))
        }

        // Mirroring the StateManager's calculation
        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 120, weight: .bold, design: .monospaced))
          .foregroundColor(.white)

        HStack(spacing: 24) {
          Button(action: { stateManager.timeRemaining += 60 }) {
            Label("1 min", systemImage: "plus")
              .padding(.horizontal, 24).padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .clipShape(Capsule())
          }.buttonStyle(.plain)

          Button(action: { stateManager.transition(to: .active) }) {
            HStack {
              if !stateManager.canSkip {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                Text("Wait \(stateManager.skipSecondsRemaining)s")
              } else {
                Image(systemName: "forward.end.fill")
                Text("Skip Break")
              }
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(stateManager.canSkip ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .disabled(!stateManager.canSkip)

          Button(action: { lockMacOS() }) {
            Label("Lock Screen", systemImage: "lock.fill")
              .padding(.horizontal, 24).padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .clipShape(Capsule())
          }.buttonStyle(.plain)
        }
      }
    }
  }

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
