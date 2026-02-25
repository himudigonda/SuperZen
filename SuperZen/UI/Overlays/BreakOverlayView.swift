import AppKit
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager
  @State private var canSkip = false
  @State private var skipProgress: Double = 0
  @State private var secondsRemainingToSkip: Int = 3
  let skipDelay: Double = 3.0

  var body: some View {
    ZStack {
      // Authentic behind-window blur
      VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
        .ignoresSafeArea()

      if #available(macOS 15.0, *) {
        MeshGradient(
          width: 3, height: 3,
          points: [
            [0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.8, 0.2], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
          ],
          colors: [
            .black, Color(hex: "1A237E"), .black,
            Color(hex: "4A148C"), Color(hex: "01579B"), .black,
            .black, Color(hex: "311B92"), .black,
          ]
        )
        .ignoresSafeArea()
        .opacity(0.4)
      } else {
        LinearGradient(
          colors: [.black, Color(hex: "1A237E"), .black], startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .opacity(0.6)
      }

      VStack(spacing: 50) {
        Text("Current time is \(Date().formatted(date: .omitted, time: .shortened))")
          .font(.system(size: 16, weight: .medium))
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
          .font(.system(size: 120, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
          .contentTransition(.numericText())

        HStack(spacing: 24) {
          ZenBreakActionPill(icon: "plus", text: "1 min") {
            withAnimation { stateManager.timeRemaining += 60 }
          }

          // Polished Skip Button
          Button(action: { stateManager.transition(to: .active) }) {
            HStack(spacing: 10) {
              if !canSkip {
                // Custom Animated Ring
                ZStack {
                  Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 14, height: 14)
                  Circle()
                    .trim(from: 0, to: skipProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
                }
                Text("Wait \(secondsRemainingToSkip)s to skip")
                  .font(.system(size: 14, weight: .medium, design: .monospaced))
              } else {
                Image(systemName: "forward.end.fill")
                Text("Skip Break")
                  .font(.system(size: 14, weight: .medium))
              }
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(canSkip ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            .clipShape(Capsule())
            // Fix jitter on hover
            .contentShape(Capsule())
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
    canSkip = false
    skipProgress = 0
    secondsRemainingToSkip = Int(skipDelay)

    withAnimation(.linear(duration: skipDelay)) {
      skipProgress = 1.0
    }

    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      if secondsRemainingToSkip > 1 {
        secondsRemainingToSkip -= 1
      } else {
        canSkip = true
        timer.invalidate()
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
      .contentShape(Capsule())
    }.buttonStyle(.plain)
  }
}
