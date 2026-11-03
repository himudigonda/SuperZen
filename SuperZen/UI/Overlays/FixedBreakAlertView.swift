import SuperZenCore
import SwiftUI

struct FixedBreakAlertView: View {
  @EnvironmentObject var stateManager: StateManager
  var isPreview: Bool = false
  private let snoozeDuration: TimeInterval = SettingsCatalog.defaultSnoozeDuration

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.xl, style: .continuous)
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center) {
        Label(
          "\(Int(stateManager.continuousFocusTime / 60)) mins without a break",
          systemImage: "bolt.fill"
        )
        .font(ZenFont.labelMedium)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(ZenColor.onWarningContainer)
        .padding(.horizontal, ZenSpacing.sm)
        .padding(.vertical, ZenSpacing.xxs)
        .background(ZenColor.warningContainer, in: Capsule())
        .accessibilitySortPriority(3)

        Spacer(minLength: ZenSpacing.sm)

        Button(action: { OverlayCoordinator.shared.dismiss(.alert) }) {
          Image(systemName: "xmark")
        }
        .buttonStyle(ZenIconButtonStyle(kind: .tonal, size: ZenSpacing.xl))
        .accessibilityLabel("Dismiss reminder")
      }

      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text(formatTime(displaySeconds))
          .font(ZenFont.alertTimer)
          .foregroundStyle(ZenColor.onSurface)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel("\(SpokenTimeFormatter.spokenTime(displaySeconds)) until your break")

        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, ZenSpacing.xs)
      .accessibilityElement(children: .combine)
      .accessibilitySortPriority(2)

      Spacer(minLength: ZenSpacing.sm)

      HStack(spacing: ZenSpacing.xs) {
        Button(action: startNow) {
          Text("Start break now").minimumScaleFactor(0.7)
        }
        .buttonStyle(ZenButtonStyle(kind: .filled, size: .small))

        if stateManager.difficulty != .hardcore {
          Button(action: skipBreak) {
            Text("Skip").minimumScaleFactor(0.7)
          }
          .buttonStyle(ZenButtonStyle(kind: .tonal, size: .small))
        }

        Button(action: snooze) {
          Text("Snooze \(DurationFormat.compact(snoozeDuration))").minimumScaleFactor(0.7)
        }
        .buttonStyle(ZenButtonStyle(kind: .tonal, size: .small))
      }
      .accessibilitySortPriority(1)
    }
    .padding(.horizontal, ZenSpacing.lg)
    .padding(.top, ZenSpacing.md)
    .padding(.bottom, ZenSpacing.lg)
    .accessibilityElement(children: .contain)
    .frame(width: OverlayGeometry.alertCardSize.width, height: OverlayGeometry.alertCardSize.height)
    .background(ZenColor.surfaceContainerHigh, in: shape)
    .overlay(alignment: .bottom) {
      ZenLinearProgress(
        value: countdownProgress, tint: .primary, track: .surfaceContainerHighest,
        height: ZenSpacing.xxs
      )
      .zenAnimation(.standard, value: countdownProgress)
      .accessibilityHidden(true)
      .padding(.horizontal, ZenSpacing.lg)
      .padding(.bottom, ZenSpacing.xs)
    }
    .overlay(shape.strokeBorder(ZenColor.outlineVariant, lineWidth: 1))
    .zenElevation(.level3)
    .padding(.horizontal, OverlayGeometry.alertInset.width)
    .padding(.vertical, OverlayGeometry.alertInset.height)
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var countdownProgress: Double {
    let lead = stateManager.nudgeLeadTime
    guard lead > 0 else { return 0 }
    return min(1, max(0, displaySeconds / lead))
  }

  private var displaySeconds: TimeInterval {
    isPreview ? stateManager.nudgeLeadTime : stateManager.timeRemaining
  }

  private func startNow() {
    if isPreview {
      OverlayCoordinator.shared.dismiss(.alert)
    } else {
      stateManager.startBreak()
    }
  }

  private func snooze() {
    if isPreview {
      OverlayCoordinator.shared.dismiss(.alert)
    } else {
      stateManager.snoozeNudge(by: snoozeDuration)
    }
  }

  private func skipBreak() {
    if isPreview {
      OverlayCoordinator.shared.dismiss(.alert)
    } else {
      stateManager.skipBreak()
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
