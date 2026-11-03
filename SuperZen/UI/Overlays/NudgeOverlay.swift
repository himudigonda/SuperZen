import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    HStack(spacing: ZenSpacing.sm) {
      ZStack {
        Circle()
          .stroke(ZenColor.overlayStroke, lineWidth: 3)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(
            stateManager.isTyping
              ? AnyShapeStyle(ZenColor.overlayText) : AnyShapeStyle(ZenColor.primary),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        if stateManager.isTyping {
          Image(systemName: "pause.fill")
            .font(ZenFont.iconSmall)
            .foregroundStyle(ZenColor.overlayText)
        } else {
          Text(Int(max(0, ceil(stateManager.timeRemaining))), format: .number)
            .font(ZenFont.labelMedium.weight(.heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(ZenColor.overlayText)
        }
      }
      .frame(width: ZenSpacing.xxl, height: ZenSpacing.xxl)

      VStack(alignment: .leading, spacing: 0) {
        Text(verbatim: "SuperZen")
          .font(ZenFont.labelLarge)
          .foregroundStyle(ZenColor.overlayText)
        Text(stateManager.isTyping ? "Typing..." : "Rest your eyes")
          .font(ZenFont.labelMedium)
          .foregroundStyle(ZenColor.overlayTextSecondary)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, ZenSpacing.sm)
    .frame(width: 210, height: 54)
    .background {
      Capsule(style: .circular).fill(ZenColor.overlaySurface)
      Capsule(style: .circular).strokeBorder(ZenColor.overlayStroke, lineWidth: 0.5)
    }
    .clipShape(Capsule(style: .circular))
    .zenElevation(.level3)
    .accessibilityHidden(true)
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var progress: CGFloat {
    let total = stateManager.nudgeLeadTime > 0 ? stateManager.nudgeLeadTime : 10.0
    return CGFloat(max(0, min(1, stateManager.timeRemaining / total)))
  }
}
