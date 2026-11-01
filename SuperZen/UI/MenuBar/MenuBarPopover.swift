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
          if stateManager.dayProgressEnabled {
            DayProgressSummary(progress: stateManager.dayProgress)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if menu.isPaused { pausedBanner }
      actions
      Divider().overlay(ZenColor.divider)
      footer
    }
    .padding(ZenSpacing.lg)
    .frame(width: 340)
    .background(ZenCanvasBackground())
    .zenThemed()
    .zenAnimation(.standard, value: menu.glyph)
  }

  private var header: some View {
    HStack(spacing: ZenSpacing.xs) {
      Image(systemName: menu.glyph.symbolName)
        .foregroundStyle(menu.isPaused ? AnyShapeStyle(ZenColor.warning) : AnyShapeStyle(ZenColor.accent))
        .accessibilityHidden(true)
      Text(menu.glyph.title)
        .font(ZenFont.headline)
        .foregroundStyle(ZenColor.textPrimary)
      Spacer()
      Text(verbatim: "SuperZen")
        .font(ZenFont.captionEmphasized)
        .foregroundStyle(ZenColor.textTertiary)
    }
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
        detail: nil)
    }
  }

  private var pausedBanner: some View {
    Label {
      Text(
        menu.glyph == .scheduleSleep
          ? String(
            localized: "Outside your focus hours. Resume to start a session anyway.",
            comment: "Menu bar popover banner while sleeping on schedule")
          : String(
            localized: "Breaks and reminders are on hold until you resume.",
            comment: "Menu bar popover banner while paused")
      )
      .font(ZenFont.subheadline)
      .foregroundStyle(ZenColor.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "pause.fill").foregroundStyle(ZenColor.warning)
    }
    .padding(ZenSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .zenSurface(cornerRadius: ZenRadius.md, elevation: .flat)
    .transition(.opacity)
  }

  private var actions: some View {
    Grid(horizontalSpacing: ZenSpacing.xs, verticalSpacing: ZenSpacing.xs) {
      GridRow {
        PopoverActionButton(
          title: String(localized: "Start break", comment: "Menu bar popover action"),
          symbol: "cup.and.saucer.fill", isEnabled: menu.actions.canStartBreak
        ) { stateManager.startBreak() }
        PopoverActionButton(
          title: skipTitle, symbol: "forward.end.fill", isEnabled: menu.actions.canSkip
        ) { stateManager.skipBreak() }
      }
      GridRow {
        PopoverActionButton(
          title: String(
            localized: "Snooze \(DurationFormat.compact(timer.snoozeDuration))",
            comment: "Menu bar popover action with snooze length"),
          symbol: "zzz", isEnabled: menu.actions.canSnooze
        ) { stateManager.snoozeNudge() }
        PopoverActionButton(
          title: menu.isPaused
            ? String(localized: "Resume", comment: "Menu bar popover action")
            : String(localized: "Pause", comment: "Menu bar popover action"),
          symbol: menu.isPaused ? "play.fill" : "pause.fill",
          isEnabled: true, isProminent: menu.isPaused
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
    HStack {
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
    .buttonStyle(.plain)
    .font(ZenFont.subheadlineEmphasized)
    .foregroundStyle(ZenColor.textSecondary)
  }
}

private struct InfoLine: View {
  let title: String
  let value: String
  let detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
      Text(title)
        .font(ZenFont.caption)
        .foregroundStyle(ZenColor.textSecondary)
      Text(value)
        .font(ZenFont.bodyEmphasized)
        .foregroundStyle(ZenColor.textPrimary)
        .monospacedDigit()
      if let detail {
        Text(detail)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textTertiary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct ProgressRing: View {
  let menu: MenuBarSnapshot
  private let diameter: CGFloat = 104
  private let lineWidth: CGFloat = 8

  var body: some View {
    ZStack {
      Circle()
        .stroke(ZenColor.divider, lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: menu.progress)
        .stroke(
          menu.isPaused ? AnyShapeStyle(ZenColor.textTertiary) : AnyShapeStyle(ZenGradient.accent),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .zenAnimation(.gentle, value: menu.progress)
      VStack(spacing: 0) {
        Text(TimerStyle.clock.format(menu.remaining))
          .font(ZenFont.ringTimer)
          .foregroundStyle(menu.isPaused ? ZenColor.textSecondary : ZenColor.textPrimary)
          .contentTransition(.numericText(countsDown: true))
        Text(menu.glyph.ringCaption)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
      }
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
        .font(ZenFont.caption)
        .foregroundStyle(ZenColor.textSecondary)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(ZenColor.divider)
          Capsule()
            .fill(ZenGradient.accent)
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
      .font(ZenFont.caption)
      .foregroundStyle(ZenColor.textTertiary)
      .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PopoverActionButton: View {
  let title: String
  let symbol: String
  let isEnabled: Bool
  var isProminent = false
  let action: () -> Void

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(ZenFont.subheadlineEmphasized)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
        .padding(.vertical, ZenSpacing.xs)
        .foregroundStyle(isProminent ? AnyShapeStyle(ZenColor.onAccent) : AnyShapeStyle(ZenColor.textPrimary))
        .background {
          if isProminent {
            shape.fill(ZenGradient.accent)
          } else {
            shape.fill(.thinMaterial)
            shape.fill(ZenGradient.surface)
          }
        }
        .overlay(shape.strokeBorder(ZenColor.controlStroke, lineWidth: isProminent ? 0 : 1))
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.45)
  }
}
