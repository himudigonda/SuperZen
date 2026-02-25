import AppKit
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager
  @AppStorage(SettingKey.breakBackground) var bgType = "Wallpaper"
  @AppStorage(SettingKey.blurBackground) var useBlur = true
  @AppStorage(SettingKey.customImagePath) var customPath = ""

  var body: some View {
    ZStack {
      // Dynamic background layer driven by user settings
      backgroundLayer

      // Optional frosted glass overlay for Custom image mode
      if bgType == "Custom" && useBlur {
        VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
          .ignoresSafeArea()
      }

      VStack(spacing: 60) {
        VStack(spacing: 16) {
          Text("Take a moment to breathe")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

          Text(statusMessage)
            .font(.title2)
            .foregroundColor(.white.opacity(0.8))
        }

        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 140, weight: .bold, design: .monospaced))
          .monospacedDigit()  // Ensures numbers don't jump around
          .foregroundColor(.white)

        HStack(spacing: 20) {
          // Secondary buttons get "Frosted" look
          ZenBreakActionPill(icon: "plus", text: "1 min", isFrosted: true) {
            stateManager.timeRemaining += 60
          }

          // MAIN ACTION BUTTON (The reactive one)
          Button(action: { stateManager.transition(to: .active) }) {
            HStack(spacing: 12) {
              if stateManager.difficulty == .hardcore {
                Image(systemName: "nosign")
                Text("No skips allowed")
              } else if !stateManager.canSkip {
                ProgressView()
                  .scaleEffect(0.6)
                  .brightness(1)
                Text("Wait \(stateManager.skipSecondsRemaining)s")
              } else {
                Image(systemName: "forward.end.fill")
                Text("Skip Break")
              }
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 32).padding(.vertical, 20)
            .background(skipButtonColor)
            .clipShape(Capsule())
            .shadow(color: skipButtonColor.opacity(0.4), radius: 15, y: 8)
          }
          .buttonStyle(.plain)
          .disabled(!stateManager.canSkip)
          .animation(
            .spring(response: 0.3, dampingFraction: 0.7), value: stateManager.canSkip
          )

          ZenBreakActionPill(icon: "lock.fill", text: "Lock", isFrosted: true) {
            lockMacOS()
          }
        }
      }
    }
  }

  // MARK: - Background Engine

  @ViewBuilder
  private var backgroundLayer: some View {
    if bgType == "Custom", !customPath.isEmpty, let img = NSImage(contentsOfFile: customPath) {
      Image(nsImage: img).resizable().scaledToFill().ignoresSafeArea()
    } else if bgType == "Gradient" {
      ZStack {
        Color.black.ignoresSafeArea()
        atmosphereMesh.ignoresSafeArea().opacity(0.9)
      }
    } else {
      // "Wallpaper": show the real desktop through a conditional blur + atmosphere
      ZStack {
        if useBlur {
          VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow).ignoresSafeArea()
        } else {
          Color.black.ignoresSafeArea()
        }
        atmosphereMesh.ignoresSafeArea().opacity(0.5)
      }
    }
  }

  @ViewBuilder
  private var atmosphereMesh: some View {
    if #available(macOS 15.0, *) {
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.8, 0.2], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: atmosphereColors
      )
      .animation(.easeInOut(duration: 1.0), value: stateManager.status)
      .animation(.easeInOut(duration: 1.0), value: stateManager.canSkip)
    } else {
      LinearGradient(
        colors: [atmosphereColors[1], atmosphereColors[4], .black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .opacity(0.6)
    }
  }

  // MARK: - THE ATMOSPHERE ENGINE

  private var atmosphereColors: [Color] {
    switch stateManager.difficulty {
    case .casual:
      // Relaxing Blues
      return [
        .black, Color(hex: "0D47A1"), .black,
        Color(hex: "1976D2"), Color(hex: "00B8D4"), .black,
        .black, Color(hex: "01579B"), .black,
      ]

    case .balanced:
      if stateManager.canSkip {
        // Shift to Blue when ready to skip
        return [
          .black, Color(hex: "0D47A1"), .black,
          Color(hex: "1565C0"), Color(hex: "0288D1"), .black,
          .black, Color(hex: "01579B"), .black,
        ]
      } else {
        // High-Warning Yellow/Orange while waiting
        return [
          .black, Color(hex: "FF8F00"), .black,
          Color(hex: "FFB300"), Color(hex: "E65100"), .black,
          .black, Color(hex: "F57C00"), .black,
        ]
      }

    case .hardcore:
      // Aggressive Warning Reds
      return [
        .black, Color(hex: "B71C1C"), .black,
        Color(hex: "D32F2F"), Color(hex: "000000"), .black,
        .black, Color(hex: "880E4F"), .black,
      ]
    }
  }

  // MARK: - Dynamic Color Tints (Precise matching)

  private var skipButtonColor: Color {
    switch stateManager.difficulty {
    case .casual:
      return Color.blue
    case .balanced:
      return stateManager.canSkip ? Color.blue : Color(hex: "FFB300")
    case .hardcore:
      return Color(hex: "D32F2F")
    }
  }

  private var statusMessage: String {
    if stateManager.difficulty == .hardcore { return "Stay focused. No skips allowed." }
    if stateManager.difficulty == .balanced && !stateManager.canSkip {
      return "Almost there. Just wait a few seconds."
    }
    return "Enjoy a quick break to relax and recharge!"
  }

  // MARK: - Helpers

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))  // Use ceil so 0.1s shows as 1s
    let mins = total / 60
    let secs = total % 60
    return String(format: "%02d:%02d", mins, secs)
  }

  private func lockMacOS() {
    let libHandle = dlopen(
      "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW
    )
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
  var isFrosted: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
        Text(text)
      }
      .font(.system(size: 15, weight: .bold, design: .rounded))
      .padding(.horizontal, 24).padding(.vertical, 20)
      .background(
        isFrosted
          ? AnyView(
            VisualEffectBlur(material: .selection, blendingMode: .withinWindow)
              .opacity(0.5)
          )
          : AnyView(Color.white.opacity(0.1))
      )
      .clipShape(Capsule())
      .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }.buttonStyle(.plain)
  }
}
