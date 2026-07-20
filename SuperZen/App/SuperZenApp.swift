import AppKit
import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager()

  // DISABLE APP NAP so the StateManager heartbeat (a .main/.common RunLoop timer)
  // is never throttled or suspended while this menubar-only app is in the background.
  //
  // This MUST be a `static` so the activity token lives for the whole process. A SwiftUI
  // `struct App` is a value type that SwiftUI may copy or re-create; storing the token in a
  // plain instance `var` ties its lifetime to a transient struct copy, and once that copy is
  // released the token deallocates and App Nap silently re-enables. A `static let` is lazy,
  // so `init()` touches it to guarantee it is created exactly once on launch and retained.
  private static let backgroundActivity: NSObjectProtocol = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .background],
    reason: "SuperZen Timer and Wellness Reminders"
  )

  init() {
    SettingKey.registerDefaults()
    _ = Self.backgroundActivity  // Force one-time init; retained for the process lifetime.
  }

  /// Local SwiftData container — all telemetry stays on-device
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      FocusSession.self,
      BreakEvent.self,
      // swiftlint:disable:next trailing_comma
      WellnessEvent.self,
      WorkBlockAppUsage.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  @AppStorage(SettingKey.menuBarDisplay) var menuBarDisplay = SettingsCatalog.menuBarDisplayDefault
  @AppStorage(SettingKey.timerStyle) var timerStyle = SettingsCatalog.timerStyleDefault
  @AppStorage(SettingKey.dayProgressBarStyle) var progressStyle = SettingsCatalog
    .dayProgressBarStyleDefault
  @AppStorage(SettingKey.dayProgressMetric) var progressMetric = SettingsCatalog
    .dayProgressMetricDefault
  @AppStorage(SettingKey.dayProgressFills) var progressFills = true

  var body: some Scene {
    // We only need ONE Window now
    Window("SuperZen", id: "main") {
      ContentView(stateManager: stateManager)
        .modelContainer(sharedModelContainer)
        .onAppear {
          TelemetryService.shared.setup(context: sharedModelContainer.mainContext)
        }
    }
    .windowStyle(.hiddenTitleBar)  // Hides the ugly white Apple title bar
    .windowResizability(.automatic)

    // Menu Bar Icon
    MenuBarExtra {
      MenuBarContentView(stateManager: stateManager)
    } label: {
      MenuBarLabelView(
        stateManager: stateManager,
        menuBarDisplay: menuBarDisplay,
        timerStyle: timerStyle,
        progressStyle: progressStyle,
        progressMetric: progressMetric,
        progressFills: progressFills
      )
    }
  }
}

private struct MenuBarContentView: View {
  @ObservedObject var stateManager: StateManager
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack {
      if stateManager.dayProgressEnabled && stateManager.dayProgressPercent > 0 {
        VStack(alignment: .leading, spacing: 2) {
          Text(
            verbatim: String(localized: "\(Int(stateManager.dayProgressPercent * 100))% of workday")
          )
          .font(.headline)
          Text(formatTimeRemaining(stateManager.dayProgressTimeRemaining) + " until end of day")
            .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        Divider()
      }

      Text("SuperZen: \(menuBarStatusText)")

      Divider()

      Button("Start Break Now") {
        stateManager.transition(to: .onBreak)
      }

      Button(stateManager.status.isPaused ? "Resume" : "Pause") {
        stateManager.togglePause()
      }

      Divider()

      Button("Settings & Dashboard...") {
        // `openWindow` asks SwiftUI to (re)create the "main" Window scene if its
        // NSWindow was deallocated after being closed — the NSApp.windows lookup
        // below only finds an *existing* window, so it silently no-ops once the
        // window has ever been closed unless this is called first.
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
          $0.identifier?.rawValue == "main" || $0.title == "SuperZen"
        }) {
          window.center()
          window.makeKeyAndOrderFront(nil)
        }
      }

      Button("Quit SuperZen") {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  /// Localizes the sleeping-schedule / status branch before it is substituted into the
  /// outer "SuperZen: %@" text — format substitution never recursively localizes its
  /// argument, so this must be pre-localized here rather than inline.
  private var menuBarStatusText: String {
    stateManager.isScheduleSleeping
      ? String(
        localized: "Sleeping (scheduled)",
        comment: "Menu bar status when focus schedule keeps SuperZen sleeping outside active hours")
      : stateManager.status.localizedLabel
  }
}

private struct MenuBarLabelView: View {
  @ObservedObject var stateManager: StateManager
  let menuBarDisplay: String
  let timerStyle: String
  let progressStyle: String
  let progressMetric: String
  let progressFills: Bool

  var body: some View {
    HStack(spacing: 4) {
      if menuBarDisplay.contains("Icon") {
        Image(
          systemName:
            stateManager.isScheduleSleeping
            ? "moon.zzz.fill"
            : stateManager.status == .onBreak
              ? "eye.slash.fill"
              : stateManager.showTypingIndicator ? "keyboard.fill" : "eye.circle.fill"
        )
      }

      if menuBarDisplay.contains("text") || menuBarDisplay == "Text only" {
        if stateManager.dayProgressEnabled && stateManager.dayProgressPercent > 0 {
          DayProgressBar(
            progress: stateManager.dayProgressPercent,
            labelText: metricText,
            style: progressStyle,
            fills: progressFills
          )
        } else {
          Text(
            stateManager.isScheduleSleeping
              ? String(
                localized: "Sleeping...",
                comment: "Compact menu bar label while sleeping on schedule")
              : stateManager.showTypingIndicator
                ? String(
                  localized: "Typing",
                  comment: "Compact menu bar label while typing indicator is shown")
                : formattedTimerString
          )
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  /// Single spoken summary of the menu bar item so VoiceOver reads app state in plain
  /// language instead of an icon name plus a "12:30"-style glyph string.
  private var accessibilitySummary: String {
    if stateManager.isScheduleSleeping {
      return String(
        localized: "SuperZen, sleeping on schedule",
        comment: "VoiceOver summary for the menu bar item when sleeping on a schedule")
    }
    switch stateManager.status {
    case .onBreak:
      return String(
        localized:
          "SuperZen, on break, \(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) remaining",
        comment: "VoiceOver summary: on break, with the time remaining spoken aloud")
    case .nudge where stateManager.showTypingIndicator:
      return String(
        localized: "SuperZen, break soon, paused while you type",
        comment: "VoiceOver summary: break coming up but paused because the user is typing")
    case .nudge:
      return String(
        localized:
          "SuperZen, break soon, \(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) remaining",
        comment: "VoiceOver summary: break coming up soon, with the time remaining spoken aloud")
    case .paused:
      return String(localized: "SuperZen, paused", comment: "VoiceOver summary: paused")
    case .wellness:
      return String(
        localized: "SuperZen, wellness reminder",
        comment: "VoiceOver summary: wellness reminder active")
    case .active:
      return String(
        localized:
          "SuperZen, focusing, \(SpokenTimeFormatter.spokenTime(stateManager.timeRemaining)) until break",
        comment: "VoiceOver summary: focusing, with the time until break spoken aloud")
    }
  }

  private var metricText: String {
    let h = Int(stateManager.dayProgressTimeElapsed) / 3600
    let m = (Int(stateManager.dayProgressTimeElapsed) % 3600) / 60
    let rh = Int(stateManager.dayProgressTimeRemaining) / 3600
    let rm = (Int(stateManager.dayProgressTimeRemaining) % 3600) / 60

    switch progressMetric {
    case "pct_done":
      return "\(Int(stateManager.dayProgressPercent * 100))%"
    case "pct_remaining":
      return "\(Int((1 - stateManager.dayProgressPercent) * 100))%"
    case "min_elapsed":
      return "\(h * 60 + m)m"
    case "min_remaining":
      return "\(rm)m"
    case "hr_elapsed":
      return "\(h)h"
    case "hr_remaining":
      return "\(rh)h"
    case "hr_min_elapsed":
      return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    case "hr_min_remaining":
      return rh > 0 ? "\(rh)h \(rm)m" : "\(rm)m"
    default:
      return "\(Int(stateManager.dayProgressPercent * 100))%"
    }
  }

  private var formattedTimerString: String {
    let totalSeconds = Int(max(0, ceil(stateManager.timeRemaining)))
    let mins = totalSeconds / 60
    let secs = totalSeconds % 60

    switch timerStyle {
    case "15m":
      return "\(mins)m"
    case "15":
      return "\(mins)"
    default:
      return String(format: "%d:%02d", mins, secs)
    }
  }
}

private struct DayProgressBar: View {
  let progress: Double
  let labelText: String
  let style: String
  let fills: Bool

  private var displayProgress: Double { fills ? progress : 1.0 - progress }

  var body: some View {
    switch style {
    case "bar_only":
      barPill
    case "label_only":
      Text(labelText).font(.system(size: 11, weight: .medium, design: .rounded))
    case "bar_label_inside":
      barWithInside
    default:  // "bar_label"
      HStack(spacing: 4) {
        barPill
        Text(labelText).font(.system(size: 11, weight: .medium, design: .rounded))
      }
    }
  }

  private static let pillWidth: CGFloat = 60
  private static let pillHeight: CGFloat = 22
  private static let insideWidth: CGFloat = 84

  private var barPill: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(.black.opacity(0.35))
      Rectangle()
        .fill(.white)
        .frame(width: max(Self.pillHeight, Self.pillWidth * displayProgress))
    }
    .frame(width: Self.pillWidth, height: Self.pillHeight)
    .clipShape(Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1))
  }

  private var barWithInside: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(.black.opacity(0.35))
      Rectangle()
        .fill(.white.opacity(0.90))
        .frame(width: max(Self.pillHeight, Self.insideWidth * displayProgress))
      Text(labelText)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundColor(.black.opacity(0.75))
        .frame(width: Self.insideWidth)
    }
    .frame(width: Self.insideWidth, height: Self.pillHeight)
    .clipShape(Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1))
  }
}

private func formatTimeRemaining(_ t: TimeInterval) -> String {
  let h = Int(t) / 3600
  let m = (Int(t) % 3600) / 60
  if h > 0 {
    return "\(h) hr\(h == 1 ? "" : "s") \(m) min"
  }
  return "\(m) min"
}
