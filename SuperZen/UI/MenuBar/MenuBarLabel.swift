import SuperZenCore
import SwiftUI

struct MenuBarLabel: View {
  @ObservedObject var stateManager: StateManager
  @Environment(\.openWindow) private var openWindow
  @AppStorage(SettingKey.menuBarDisplay) private var display = SettingsCatalog.menuBarDisplayDefault
  @AppStorage(SettingKey.timerStyle) private var timerStyleRaw = SettingsCatalog.timerStyleDefault
  @AppStorage(SettingKey.dayProgressBarStyle) private var progressStyle = SettingsCatalog.dayProgressBarStyleDefault
  @AppStorage(SettingKey.dayProgressMetric) private var metricRaw = SettingsCatalog.dayProgressMetricDefault
  @AppStorage(SettingKey.dayProgressFills) private var progressFills = true

  var body: some View {
    let content = MenuBarLabelContent(
      menu: stateManager.menuBar, display: display,
      timerStyle: TimerStyle(rawValue: timerStyleRaw) ?? .clock)
    HStack(spacing: ZenSpacing.xxs) {
      if content.showsIcon {
        Image(systemName: content.menu.glyph.symbolName)
      }
      if content.showsText {
        Text(content.text)
      }
      if stateManager.dayProgressEnabled {
        DayProgressPill(
          progress: stateManager.dayProgress.fraction,
          labelText: metric.label(for: stateManager.dayProgress),
          style: progressStyle,
          fills: progressFills)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(MenuBarLabelContent.spokenSummary(for: content.menu))
    .onReceive(NotificationCenter.default.publisher(for: MainWindow.reopenRequested)) { _ in
      MainWindow.open(openWindow)
    }
  }

  private var metric: DayProgressMetric {
    DayProgressMetric(rawValue: metricRaw) ?? .percentDone
  }
}

struct MenuBarLabelContent: Equatable {
  let menu: MenuBarSnapshot
  let display: String
  let timerStyle: TimerStyle

  var showsIcon: Bool { display != "Text only" }
  var showsText: Bool { display != "Icon only" }

  var text: String {
    if menu.deferredByApp {
      return String(localized: "Waiting", comment: "Compact menu bar label while a break is deferred")
    }
    if let label = menu.glyph.compactLabel { return label }
    let time = timerStyle.format(menu.remaining)
    guard !showsIcon, menu.isOnBreak else { return time }
    return String(localized: "Break \(time)", comment: "Text only menu bar label during a break")
  }

  static func spokenSummary(for menu: MenuBarSnapshot) -> String {
    let time = SpokenTimeFormatter.spokenTime(menu.remaining)
    switch menu.glyph {
    case .focusing:
      return String(
        localized: "SuperZen, focusing, \(time) until break",
        comment: "VoiceOver summary: focusing, with the time until break spoken aloud")
    case .away:
      return String(localized: "SuperZen, away", comment: "VoiceOver summary: the user has stepped away")
    case .breakSoon:
      return String(
        localized: "SuperZen, break soon, \(time) remaining",
        comment: "VoiceOver summary: break coming up soon, with the time remaining spoken aloud")
    case .typing:
      return String(
        localized: "SuperZen, break soon, waiting while you type",
        comment: "VoiceOver summary: break coming up but held because the user is typing")
    case .shortBreak, .longBreak:
      return String(
        localized: "SuperZen, \(menu.glyph.title), \(time) remaining",
        comment: "VoiceOver summary: on a break of a given kind, with the time remaining spoken aloud")
    case .wellness:
      return String(
        localized: "SuperZen, wellness reminder", comment: "VoiceOver summary: wellness reminder active")
    case .paused:
      return String(localized: "SuperZen, paused", comment: "VoiceOver summary: paused")
    case .scheduleSleep:
      return String(
        localized: "SuperZen, sleeping on schedule",
        comment: "VoiceOver summary for the menu bar item when sleeping on a schedule")
    }
  }
}

struct DayProgressPill: View {
  let progress: Double
  let labelText: String
  let style: String
  let fills: Bool

  private static let pillWidth: CGFloat = 60
  private static let pillHeight: CGFloat = 22
  private static let insideWidth: CGFloat = 84

  private var displayProgress: Double { fills ? progress : 1 - progress }

  var body: some View {
    switch style {
    case "bar_only":
      pill(width: Self.pillWidth, fillOpacity: 1)
    case "label_only":
      Text(labelText).font(ZenFont.menuBarMetric)
    case "bar_label_inside":
      pill(width: Self.insideWidth, fillOpacity: 0.9)
        .overlay {
          Text(labelText)
            .font(ZenFont.menuBarMetricInside)
            .foregroundStyle(.black.opacity(0.75))
        }
    default:
      HStack(spacing: ZenSpacing.xxs) {
        pill(width: Self.pillWidth, fillOpacity: 1)
        Text(labelText).font(ZenFont.menuBarMetric)
      }
    }
  }

  private func pill(width: CGFloat, fillOpacity: Double) -> some View {
    ZStack(alignment: .leading) {
      Capsule().fill(.black.opacity(0.35))
      Rectangle()
        .fill(.white.opacity(fillOpacity))
        .frame(width: max(Self.pillHeight, width * displayProgress))
    }
    .frame(width: width, height: Self.pillHeight)
    .clipShape(Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
  }
}
