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
        .font(ZenFont.captionEmphasized)
        .foregroundStyle(ZenColor.warning)
        .padding(.horizontal, ZenSpacing.sm)
        .padding(.vertical, ZenSpacing.xxs)
        .background(ZenColor.warning.opacity(0.18), in: Capsule())

        Spacer()

        Button(action: { OverlayWindowManager.shared.closeFixedAlert() }) {
          Image(systemName: "xmark")
            .font(ZenFont.controlIcon)
            .foregroundStyle(ZenColor.overlayTextSecondary)
            .frame(width: ZenSpacing.xl, height: ZenSpacing.xl)
            .background(ZenColor.overlayStroke, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss reminder")
      }
      .padding(.top, ZenSpacing.lg)
      .padding(.horizontal, ZenSpacing.lg)

      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text(formatTime(displaySeconds))
          .font(ZenFont.alertTimer)
          .foregroundStyle(ZenColor.overlayText)
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel("\(SpokenTimeFormatter.spokenTime(displaySeconds)) until your break")

        Text("Almost time. Your eyes will appreciate a quick rest.")
          .font(ZenFont.body)
          .foregroundStyle(ZenColor.overlayTextSecondary)
          .lineLimit(1)
      }
      .padding(.horizontal, ZenSpacing.lg)
      .padding(.top, ZenSpacing.sm)

      Spacer()

      HStack(spacing: ZenSpacing.sm) {
        Button(action: startNow) {
          Text("Start break now")
            .font(ZenFont.bodyEmphasized)
            .foregroundStyle(ZenColor.onAccent)
            .padding(.horizontal, ZenSpacing.md)
            .padding(.vertical, ZenSpacing.xs)
            .background(ZenGradient.accent, in: Capsule())
        }
        .buttonStyle(.plain)

        if stateManager.difficulty != .hardcore {
          Divider()
            .frame(height: 14)
            .overlay(ZenColor.overlayStroke)

          Button(action: skipBreak) {
            Text("Skip")
              .font(ZenFont.body)
              .foregroundStyle(ZenColor.overlayTextSecondary)
          }
          .buttonStyle(.plain)
        }

        Button(action: snooze) {
          Text("Snooze \(Int(snoozeDuration / 60))m")
            .font(ZenFont.body)
            .foregroundStyle(ZenColor.overlayTextSecondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.bottom, ZenSpacing.lg)
      .padding(.horizontal, ZenSpacing.lg)
    }
    .frame(width: 420, height: 200)
    .background(ZenColor.overlaySurface, in: shape)
    .zenElevation(.overlay)
    .padding(.horizontal, 30)
    .padding(.vertical, 40)
    .zenThemed()
    .environment(\.colorScheme, .dark)
  }

  private var displaySeconds: TimeInterval {
    isPreview ? stateManager.nudgeLeadTime : stateManager.timeRemaining
  }

  private func startNow() {
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.startBreak()
    }
  }

  private func snooze() {
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.snoozeNudge(by: snoozeDuration)
    }
  }

  private func skipBreak() {
    if isPreview {
      OverlayWindowManager.shared.closeFixedAlert()
    } else {
      stateManager.skipBreak()
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, ceil(seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
