import AppKit
import SuperZenCore
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    ZStack {
      ZenBackgroundView(
        atmosphereColors: ZenPalette.breakAtmosphere(
          stateManager.difficulty, canSkip: stateManager.canSkip)
      )
      .zenAnimation(.ambient, value: stateManager.canSkip)

      VStack(spacing: ZenSpacing.xxxl) {
        VStack(spacing: ZenSpacing.md) {
          Text("Take a moment to breathe")
            .font(ZenFont.overlayHero)
            .foregroundStyle(ZenColor.overlayText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityAddTraits(.isHeader)

          Text(statusMessage)
            .font(ZenFont.titleLarge)
            .foregroundStyle(ZenColor.overlayTextSecondary)
        }

        Text(formatTime(stateManager.timeRemaining))
          .font(ZenFont.overlayTimer)
          .foregroundStyle(ZenColor.overlayText)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel(
            "\(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) of break remaining")

        HStack(spacing: ZenSpacing.lg) {
          ZenBreakActionPill(icon: "plus", text: "1 min") {
            stateManager.extendBreak(by: 60)
          }
          .accessibilityLabel("Add one minute to break")

          skipButton

          ZenBreakActionPill(icon: "lock.fill", text: "Lock") {
            stateManager.lockScreen()
          }
          .accessibilityLabel("Lock screen")
        }
      }
      .padding(ZenSpacing.xxxl)
    }
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var skipButton: some View {
    Button(action: { stateManager.skipBreak() }) {
      HStack(spacing: ZenSpacing.sm) {
        if stateManager.difficulty == .hardcore {
          Image(systemName: "nosign")
          Text("No skips allowed")
        } else if !stateManager.canSkip {
          ZenLoadingIndicator(tint: .overlayText)
          Text("Wait \(stateManager.skipSecondsRemaining)s")
        } else {
          Image(systemName: "forward.end.fill")
          Text("Skip Break")
        }
      }
    }
    .buttonStyle(ZenButtonStyle(kind: .overlay, size: .large))
    .disabled(!stateManager.canSkip)
    .zenAnimation(.emphasized, value: stateManager.canSkip)
    .accessibilityLabel(skipAccessibilityLabel)
  }

  private var statusMessage: String {
    if stateManager.difficulty == .hardcore {
      return String(
        localized: "Stay focused. No skips allowed.",
        comment: "Break screen status message shown in hardcore mode")
    }
    if stateManager.difficulty == .balanced && !stateManager.canSkip {
      return String(
        localized: "Almost there. Just wait a few seconds.",
        comment: "Break screen status message while balanced-mode skip lock is active")
    }
    return String(
      localized: "Enjoy a quick break to relax and recharge!",
      comment: "Default break screen status message")
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    let mins = total / 60
    let secs = total % 60
    return String(format: "%02d:%02d", mins, secs)
  }

  private var skipAccessibilityLabel: String {
    switch stateManager.difficulty {
    case .hardcore:
      return String(
        localized: "Skipping disabled in hardcore mode",
        comment: "VoiceOver label for the disabled skip button in hardcore mode")
    case .balanced, .casual:
      return stateManager.canSkip
        ? String(localized: "Skip break", comment: "VoiceOver label for the enabled skip button")
        : String(
          localized: "Skip available in \(stateManager.skipSecondsRemaining) seconds",
          comment: "VoiceOver label for the skip button while still locked, with seconds remaining")
    }
  }
}

struct ZenBreakActionPill: View {
  let icon: String
  let text: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(text, systemImage: icon)
    }
    .buttonStyle(ZenButtonStyle(kind: .overlay, size: .large))
  }
}
