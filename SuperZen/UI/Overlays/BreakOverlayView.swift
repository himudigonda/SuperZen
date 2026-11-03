import AppKit
import SuperZenCore
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(spacing: ZenSpacing.xxl) {
      VStack(spacing: ZenSpacing.sm) {
        Text("Take a moment to breathe")
          .font(ZenFont.overlayHero)
          .foregroundStyle(ZenColor.overlayText)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.6)
          .accessibilityAddTraits(.isHeader)

        Text(statusMessage)
          .font(ZenFont.titleLarge)
          .foregroundStyle(ZenColor.overlayTextSecondary)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
      }

      VStack(spacing: ZenSpacing.lg) {
        Text(formatTime(stateManager.timeRemaining))
          .font(ZenFont.overlayTimer)
          .foregroundStyle(ZenColor.overlayText)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel(
            "\(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) of break remaining")

        ZenLinearProgress(
          value: breakProgress, tint: .overlayText, track: .overlayTrack,
          height: ZenOverlayMetrics.progressHeight
        )
        .frame(maxWidth: ZenOverlayMetrics.progressWidth)
        .zenAnimation(.standard, value: breakProgress)
        .accessibilityHidden(true)
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: ZenSpacing.md) { actions }
        VStack(spacing: ZenSpacing.md) { actions }
      }
    }
    .frame(maxWidth: ZenOverlayMetrics.contentMaxWidth)
    .padding(ZenSpacing.xxxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlayContentScale()
    .background {
      ZenBackgroundView(
        atmosphereColors: ZenPalette.breakAtmosphere(
          stateManager.difficulty, canSkip: stateManager.canSkip)
      )
      .zenAnimation(.ambient, value: stateManager.canSkip)
    }
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  @ViewBuilder
  private var actions: some View {
    OverlayActionButton(icon: "plus", title: "Add 1 min") {
      stateManager.extendBreak(by: 60)
    }
    .accessibilityLabel("Add one minute to break")

    skipButton

    OverlayActionButton(icon: "lock.fill", title: "Lock screen") {
      stateManager.lockScreen()
    }
    .accessibilityLabel("Lock screen")
  }

  private var breakProgress: Double {
    let total = stateManager.breakDuration
    guard total > 0 else { return 0 }
    return 1 - stateManager.timeRemaining / total
  }

  private var skipButton: some View {
    Button(action: { stateManager.skipBreak() }) {
      if stateManager.difficulty == .hardcore && !stateManager.canSkip {
        Label("No skips allowed", systemImage: "nosign")
      } else if !stateManager.canSkip {
        Label("Wait \(stateManager.skipSecondsRemaining)s", systemImage: "hourglass")
      } else {
        Label("Skip break", systemImage: "forward.end.fill")
      }
    }
    .buttonStyle(OverlayActionStyle())
    .disabled(!stateManager.canSkip)
    .zenAnimation(.emphasized, value: stateManager.canSkip)
    .accessibilityLabel(skipAccessibilityLabel)
  }

  private var statusMessage: String {
    if stateManager.difficulty == .hardcore && stateManager.canSkip {
      return String(
        localized: "You're on a call. You can skip this break.",
        comment: "Break screen status message in hardcore mode while a call lets the break be skipped")
    }
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
    case .hardcore where !stateManager.canSkip:
      return String(
        localized: "Skipping disabled in hardcore mode",
        comment: "VoiceOver label for the disabled skip button in hardcore mode")
    case .hardcore, .balanced, .casual:
      return stateManager.canSkip
        ? String(localized: "Skip break", comment: "VoiceOver label for the enabled skip button")
        : String(
          localized: "Skip available in \(stateManager.skipSecondsRemaining) seconds",
          comment: "VoiceOver label for the skip button while still locked, with seconds remaining")
    }
  }
}
