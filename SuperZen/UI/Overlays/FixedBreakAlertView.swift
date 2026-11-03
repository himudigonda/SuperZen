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
        .foregroundStyle(ZenColor.onWarningContainer)
        .padding(.horizontal, ZenSpacing.sm)
        .padding(.vertical, ZenSpacing.xxs)
        .background(ZenColor.warningContainer, in: Capsule())
        .accessibilitySortPriority(3)

        Spacer()

        Button(action: { OverlayCoordinator.shared.dismiss(.alert) }) {
          Image(systemName: "xmark")
        }
        .buttonStyle(ZenIconButtonStyle(kind: .tonal, size: ZenSpacing.xl))
        .accessibilityLabel("Dismiss reminder")
      }
      .padding(.top, ZenSpacing.lg)
      .padding(.horizontal, ZenSpacing.lg)

      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text(formatTime(displaySeconds))
          .font(ZenFont.alertTimer)
          .foregroundStyle(ZenColor.onSurface)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel("\(SpokenTimeFormatter.spokenTime(displaySeconds)) until your break")

        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .lineLimit(1)
      }
      .padding(.horizontal, ZenSpacing.lg)
      .padding(.top, ZenSpacing.sm)
      .accessibilityElement(children: .combine)
      .accessibilitySortPriority(2)

      Spacer()

      HStack(spacing: ZenSpacing.sm) {
        Button(action: startNow) {
          Text("Start break now")
        }
        .buttonStyle(.zenFilled)

        if stateManager.difficulty != .hardcore {
          ZenVerticalDivider(height: 14)

          Button(action: skipBreak) {
            Text("Skip")
          }
          .buttonStyle(ZenButtonStyle(kind: .text, size: .small))
        }

        Button(action: snooze) {
          Text("Snooze \(DurationFormat.compact(snoozeDuration))")
        }
        .buttonStyle(ZenButtonStyle(kind: .text, size: .small))
      }
      .padding(.bottom, ZenSpacing.lg)
      .padding(.horizontal, ZenSpacing.lg)
      .accessibilitySortPriority(1)
    }
    .accessibilityElement(children: .contain)
    .frame(width: OverlayGeometry.alertCardSize.width, height: OverlayGeometry.alertCardSize.height)
    .background(ZenColor.surfaceContainerHigh, in: shape)
    .zenElevation(.level3)
    .padding(.horizontal, OverlayGeometry.alertInset.width)
    .padding(.vertical, OverlayGeometry.alertInset.height)
    .zenThemed()
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
