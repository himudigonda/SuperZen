import AppKit
import SuperZenCore
import SwiftUI

struct BreakOverlayView: View {
  @EnvironmentObject var stateManager: StateManager
  var tip: BreakTip?

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

        Text(copy.statusMessage)
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

        if let tip { BreakTipView(tip: tip) }
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

    if copy.showsLater {
      OverlayActionButton(icon: "clock.arrow.circlepath", title: "Later") {
        stateManager.postponeBreak()
      }
      .disabled(!copy.canPostpone)
      .accessibilityLabel(copy.laterAccessibilityLabel)
    }

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

  private var copy: BreakOverlayCopy { stateManager.breakOverlayCopy }

  private var skipButton: some View {
    Button(action: { stateManager.skipBreak() }) {
      Label(copy.skipTitle, systemImage: skipSymbol)
    }
    .buttonStyle(OverlayActionStyle())
    .disabled(!stateManager.canSkip)
    .zenAnimation(.emphasized, value: stateManager.canSkip)
    .accessibilityLabel(copy.skipAccessibilityLabel)
  }

  private var skipSymbol: String {
    if stateManager.difficulty == .hardcore && !stateManager.canSkip { return "nosign" }
    return stateManager.canSkip ? "forward.end.fill" : "hourglass"
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    let mins = total / 60
    let secs = total % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}
