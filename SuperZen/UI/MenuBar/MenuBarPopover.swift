import SuperZenCore
import SwiftUI

struct MenuBarPopover: View {
  @ObservedObject var stateManager: StateManager
  @Environment(\.openWindow) private var openWindow

  private var menu: MenuBarSnapshot { stateManager.menuBar }
  private var timer: TimerSettings { stateManager.session.settings.timer }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.md) {
      header
      HStack(alignment: .center, spacing: ZenSpacing.lg) {
        ProgressRing(menu: menu)
        VStack(alignment: .leading, spacing: ZenSpacing.sm) {
          scheduleSummary
          if stateManager.dayProgressEnabled && !menu.isPaused {
            DayProgressSummary(progress: stateManager.dayProgress)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      actions
      ZenDivider()
      footer
    }
    .padding(ZenSpacing.lg)
    .frame(width: 340)
    .background(ZenColor.surfaceContainerLow, ignoresSafeAreaEdges: .all)
    .zenOverlayHost()
    .zenThemed()
    .zenAnimation(.standard, value: menu.glyph)
  }

  private var header: some View {
    ZenBadge(
      text: menu.glyph.title,
      tone: menu.isPaused ? .warning : .primary,
      systemImage: menu.glyph.symbolName
    )
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var scheduleSummary: some View {
    if let nextBreak = menu.nextBreakAt {
      InfoLine(
        title: String(localized: "Next break", comment: "Menu bar popover label"),
        value: nextBreak.formatted(date: .omitted, time: .shortened),
        detail: "\(menu.nextBreakKind.title), \(DurationFormat.compact(timer.duration(of: menu.nextBreakKind)))")
    } else if let kind = menu.currentBreakKind {
      InfoLine(
        title: String(localized: "Back to work at", comment: "Menu bar popover label during a break"),
        value: stateManager.currentTime.addingTimeInterval(menu.remaining)
          .formatted(date: .omitted, time: .shortened),
        detail: kind.title)
    } else {
      InfoLine(
        title: String(localized: "Next break", comment: "Menu bar popover label"),
        value: String(localized: "On hold", comment: "Menu bar popover: no break scheduled"),
        detail: pausedDetail)
    }
  }

  private var pausedDetail: String? {
    guard menu.isPaused else { return nil }
    return menu.glyph == .scheduleSleep
      ? String(
        localized: "Outside your focus hours. Resume to start a session anyway.",
        comment: "Menu bar popover banner while sleeping on schedule")
      : String(
        localized: "Breaks and reminders are on hold until you resume.",
        comment: "Menu bar popover banner while paused")
  }

  private var actions: some View {
    Grid(horizontalSpacing: ZenSpacing.xs, verticalSpacing: ZenSpacing.xs) {
      GridRow {
        PopoverActionButton(
          title: String(localized: "Start break", comment: "Menu bar popover action"),
          symbol: "cup.and.saucer.fill", isEnabled: menu.actions.canStartBreak, style: .zenTonal
        ) { stateManager.startBreak() }
        PopoverActionButton(
          title: skipTitle, symbol: "forward.end.fill", isEnabled: menu.actions.canSkip, style: .zenTonal
        ) { stateManager.skipBreak() }
      }
      GridRow {
        PopoverActionButton(
          title: String(
            localized: "Snooze \(DurationFormat.compact(timer.snoozeDuration))",
            comment: "Menu bar popover action with snooze length"),
          symbol: "zzz", isEnabled: menu.actions.canSnooze,
          style: menu.isPaused ? .zenOutlined : .zenTonal
        ) { stateManager.snoozeNudge() }
        PopoverActionButton(
          title: menu.isPaused
            ? String(localized: "Resume", comment: "Menu bar popover action")
            : String(localized: "Pause", comment: "Menu bar popover action"),
          symbol: menu.isPaused ? "play.fill" : "pause.fill",
          isEnabled: true,
          style: menu.isPaused ? .zenFilled : .zenTonal
        ) { stateManager.togglePause() }
      }
    }
  }

  private var skipTitle: String {
    menu.actions.skipUnlocksIn > 0
      ? String(
        localized: "Skip in \(menu.actions.skipUnlocksIn)s",
        comment: "Menu bar popover action while skip is still locked")
      : String(localized: "Skip break", comment: "Menu bar popover action")
  }

  private var footer: some View {
    HStack(spacing: 0) {
      Button {
        MainWindow.open(openWindow)
      } label: {
        Label(
          String(localized: "Open SuperZen", comment: "Menu bar popover footer action"),
          systemImage: "gearshape")
      }
      .keyboardShortcut(",")
      Spacer()
      Button(String(localized: "Quit", comment: "Menu bar popover footer action")) {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    }
    .buttonStyle(ZenButtonStyle(kind: .text, size: .small))
    .padding(.horizontal, -ZenSpacing.xs)
    .padding(.vertical, -ZenSpacing.xxs)
  }
}

private struct InfoLine: View {
  let title: String
  let value: String
  let detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
      Text(title)
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
      Text(value)
        .font(ZenFont.titleSmall)
        .foregroundStyle(ZenColor.onSurface)
        .monospacedDigit()
      if let detail {
        Text(detail)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct ProgressRing: View {
  let menu: MenuBarSnapshot
  private let diameter: CGFloat = 112
  private let lineWidth: CGFloat = 7

  var body: some View {
    ZStack {
      ZenCircularProgress(
        value: menu.progress,
        lineWidth: lineWidth,
        tint: menu.isPaused ? ZenColor.onSurfaceVariant : ZenColor.primary
      )
      .zenAnimation(.gentle, value: menu.progress)
      VStack(spacing: 0) {
        Text(TimerStyle.clock.format(menu.remaining))
          .font(ZenFont.ringTimer)
          .foregroundStyle(menu.isPaused ? ZenColor.onSurfaceVariant : ZenColor.onSurface)
          .contentTransition(.numericText(countsDown: true))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(menu.glyph.ringCaption)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .padding(.horizontal, lineWidth + ZenSpacing.xxs)
    }
    .frame(width: diameter, height: diameter)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(MenuBarLabelContent.spokenSummary(for: menu))
    .accessibilityValue(Text(menu.progress, format: .percent.precision(.fractionLength(0))))
  }
}

private struct DayProgressSummary: View {
  let progress: DayProgress

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      Text(String(localized: "Workday", comment: "Menu bar popover day progress label"))
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(ZenColor.outlineVariant)
          Capsule()
            .fill(ZenColor.primary)
            .frame(width: proxy.size.width * progress.fraction)
        }
      }
      .frame(height: ZenSpacing.xs)
      Text(
        String(
          localized:
            "\(DayProgressMetric.percentDone.label(for: progress)) done, \(DayProgressMetric.timeRemaining.label(for: progress)) left",
          comment: "Menu bar popover day progress detail")
      )
      .font(ZenFont.bodySmall)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PopoverActionButton: View {
  let title: String
  let symbol: String
  let isEnabled: Bool
  let style: ZenButtonStyle
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(style)
    .disabled(!isEnabled)
  }
}
