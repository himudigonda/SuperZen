import SuperZenCore
import SwiftUI

struct BreakBannerView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.xl, style: .continuous)
    let copy = stateManager.breakOverlayCopy
    HStack(spacing: ZenSpacing.md) {
      VStack(alignment: .leading, spacing: ZenSpacing.xs) {
        Text(formatTime(stateManager.timeRemaining))
          .font(ZenFont.ringTimer)
          .foregroundStyle(ZenColor.onSurface)
          .lineLimit(1)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel(
            "\(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) of break remaining")

        ZenLinearProgress(
          value: breakProgress, tint: .primary, track: .surfaceContainerHighest,
          height: ZenSpacing.xxs
        )
        .zenAnimation(.standard, value: breakProgress)
        .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if copy.showsLater {
        Button(action: { stateManager.postponeBreak() }) {
          Text("Later").lineLimit(1).minimumScaleFactor(0.6)
        }
        .buttonStyle(ZenButtonStyle(kind: .tonal, size: .small))
        .disabled(!copy.canPostpone)
        .accessibilityLabel(copy.laterAccessibilityLabel)
      }

      Button(action: { stateManager.skipBreak() }) {
        Text(copy.skipTitle).lineLimit(1).minimumScaleFactor(0.6)
      }
      .buttonStyle(ZenButtonStyle(kind: .filled, size: .small))
      .disabled(!copy.canSkip)
      .zenAnimation(.emphasized, value: copy.canSkip)
      .accessibilityLabel(copy.skipAccessibilityLabel)
    }
    .padding(.horizontal, ZenSpacing.lg)
    .frame(width: OverlayGeometry.bannerCardSize.width, height: OverlayGeometry.bannerCardSize.height)
    .background(ZenColor.surfaceContainerHigh, in: shape)
    .overlay(shape.strokeBorder(ZenColor.outlineVariant, lineWidth: 1))
    .zenElevation(.level3)
    .padding(.horizontal, OverlayGeometry.bannerInset.width)
    .padding(.vertical, OverlayGeometry.bannerInset.height)
    .accessibilityElement(children: .contain)
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var breakProgress: Double {
    let total = stateManager.breakDuration
    guard total > 0 else { return 0 }
    return 1 - stateManager.timeRemaining / total
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
