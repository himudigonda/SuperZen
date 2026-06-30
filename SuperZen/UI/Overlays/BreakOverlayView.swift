import AppKit
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    ZStack {
      // Unified background engine — animates when canSkip changes (balanced: orange→blue)
      ZenBackgroundView(atmosphereColors: atmosphereColors)
        .animation(.easeInOut(duration: 1.0), value: stateManager.canSkip)

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
          .monospacedDigit()
          .foregroundColor(.white)
          .accessibilityLabel("\(spokenTime(stateManager.timeRemaining)) of break remaining")

        HStack(spacing: 20) {
          ZenBreakActionPill(icon: "plus", text: "1 min", isFrosted: true) {
            stateManager.extendBreak(by: 60)
          }
          .accessibilityLabel("Add one minute to break")

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
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stateManager.canSkip)
          .accessibilityLabel(skipAccessibilityLabel)

          ZenBreakActionPill(icon: "lock.fill", text: "Lock", isFrosted: true) {
            lockMacOS()
          }
          .accessibilityLabel("Lock screen")
        }
      }
    }
  }

  // MARK: - Atmosphere colors (difficulty-reactive)

  private var atmosphereColors: [Color] {
    switch stateManager.difficulty {
    case .casual:
      return [
        .black, Color(hex: "0D47A1"), .black,
        Color(hex: "1976D2"), Color(hex: "00B8D4"), .black,
        .black, Color(hex: "01579B"), .black,
      ]
    case .balanced:
      if stateManager.canSkip {
        return [
          .black, Color(hex: "0D47A1"), .black,
          Color(hex: "1565C0"), Color(hex: "0288D1"), .black,
          .black, Color(hex: "01579B"), .black,
        ]
      } else {
        return [
          .black, Color(hex: "FF8F00"), .black,
          Color(hex: "FFB300"), Color(hex: "E65100"), .black,
          .black, Color(hex: "F57C00"), .black,
        ]
      }
    case .hardcore:
      return [
        .black, Color(hex: "B71C1C"), .black,
        Color(hex: "D32F2F"), Color(hex: "000000"), .black,
        .black, Color(hex: "880E4F"), .black,
      ]
    }
  }

  // MARK: - UI helpers

  private var skipButtonColor: Color {
    switch stateManager.difficulty {
    case .casual: return Color.blue
    case .balanced: return stateManager.canSkip ? Color.blue : Color(hex: "FFB300")
    case .hardcore: return Color(hex: "D32F2F")
    }
  }

  private var statusMessage: String {
    if stateManager.difficulty == .hardcore { return "Stay focused. No skips allowed." }
    if stateManager.difficulty == .balanced && !stateManager.canSkip {
      return "Almost there. Just wait a few seconds."
    }
    return "Enjoy a quick break to relax and recharge!"
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    let mins = total / 60
    let secs = total % 60
    return String(format: "%02d:%02d", mins, secs)
  }

  /// VoiceOver-friendly spoken form of the countdown, e.g. "2 minutes 30 seconds".
  private func spokenTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    let mins = total / 60
    let secs = total % 60
    let minPart = mins > 0 ? "\(mins) minute\(mins == 1 ? "" : "s")" : ""
    let secPart = secs > 0 ? "\(secs) second\(secs == 1 ? "" : "s")" : ""
    if minPart.isEmpty && secPart.isEmpty { return "0 seconds" }
    return [minPart, secPart].filter { !$0.isEmpty }.joined(separator: " ")
  }

  /// State-aware label so VoiceOver conveys why the skip button is or isn't actionable.
  private var skipAccessibilityLabel: String {
    switch stateManager.difficulty {
    case .hardcore: return "Skipping disabled in hardcore mode"
    case .balanced, .casual:
      return stateManager.canSkip
        ? "Skip break" : "Skip available in \(stateManager.skipSecondsRemaining) seconds"
    }
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
