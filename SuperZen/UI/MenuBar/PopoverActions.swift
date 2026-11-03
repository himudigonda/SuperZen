import SuperZenCore
import SwiftUI

struct PopoverActions: View {
  @ObservedObject var stateManager: StateManager
  let dismiss: () -> Void

  private var menu: MenuBarSnapshot { stateManager.menuBar }
  private var timer: TimerSettings { stateManager.session.settings.timer }

  var body: some View {
    Grid(horizontalSpacing: ZenSpacing.xs, verticalSpacing: ZenSpacing.xs) {
      GridRow {
        PopoverActionButton(
          title: String(localized: "Start break", comment: "Menu bar popover action"),
          symbol: "cup.and.saucer.fill", isEnabled: menu.actions.canStartBreak, style: .zenTonal
        ) {
          dismiss()
          stateManager.startBreak()
        }
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
        pauseControl
      }
      GridRow {
        PopoverActionButton(
          title: String(localized: "Later", comment: "Menu bar popover action that postpones the next break"),
          symbol: "clock.arrow.circlepath", isEnabled: menu.actions.canPostpone, style: .zenOutlined
        ) { stateManager.postponeBreak() }
        .gridCellColumns(2)
      }
    }
  }

  @ViewBuilder private var pauseControl: some View {
    if menu.isPaused {
      PopoverActionButton(
        title: String(localized: "Resume", comment: "Menu bar popover action"),
        symbol: "play.fill", isEnabled: true, style: .zenFilled
      ) { stateManager.togglePause() }
    } else {
      ZenMenu(items: Self.pauseItems(for: stateManager), style: .tonal) {
        Label(String(localized: "Pause", comment: "Menu bar popover action"), systemImage: "pause.fill")
          .lineLimit(1)
          .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity)
    }
  }

  static func pauseItems(for stateManager: StateManager) -> [ZenMenuItem] {
    PausePreset.allCases.map { preset in
      .action(id: preset.rawValue, preset.title) {
        let schedule = stateManager.session.settings.schedule
        stateManager.pause(
          for: preset.duration(at: stateManager.currentTime, schedule: schedule, calendar: .current))
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
}

extension PausePreset {
  var title: String {
    switch self {
    case .fifteenMinutes: return String(localized: "15 minutes", comment: "Menu bar popover pause option")
    case .oneHour: return String(localized: "1 hour", comment: "Menu bar popover pause option")
    case .twoHours: return String(localized: "2 hours", comment: "Menu bar popover pause option")
    case .untilTomorrow: return String(localized: "Until tomorrow", comment: "Menu bar popover pause option")
    }
  }
}

struct PopoverActionButton: View {
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
