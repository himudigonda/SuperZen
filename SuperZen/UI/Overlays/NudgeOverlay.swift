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
              ? AnyShapeStyle(ZenColor.overlayTextSecondary) : AnyShapeStyle(ZenColor.warning),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        if stateManager.isTyping {
          Image(systemName: "pause.fill")
            .font(ZenFont.controlIcon)
            .foregroundStyle(ZenColor.overlayTextSecondary)
        } else {
          Text(Int(max(0, ceil(stateManager.timeRemaining))), format: .number)
            .font(ZenFont.roundedCaption.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(ZenColor.overlayText)
        }
      }
      .frame(width: ZenSpacing.xxl, height: ZenSpacing.xxl)

      VStack(alignment: .leading, spacing: 0) {
        Text(verbatim: "SuperZen")
          .font(ZenFont.roundedLabel)
          .foregroundStyle(ZenColor.overlayText)
        Text(stateManager.isTyping ? "Typing..." : "Rest your eyes")
          .font(ZenFont.roundedCaption)
          .foregroundStyle(ZenColor.overlayTextSecondary)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, ZenSpacing.sm)
    .frame(width: 210, height: 54)
    .background {
      Capsule().fill(ZenColor.overlaySurface)
      Capsule().strokeBorder(ZenColor.overlayStroke, lineWidth: 0.5)
    }
    .clipShape(Capsule())
    .accessibilityHidden(true)
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var progress: CGFloat {
    let total = stateManager.nudgeLeadTime > 0 ? stateManager.nudgeLeadTime : 10.0
    return CGFloat(max(0, min(1, stateManager.timeRemaining / total)))
  }
}
