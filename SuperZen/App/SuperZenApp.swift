import AppKit
import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager()

  // FIX: Persistent activity object to prevent App Nap
  private var activity: NSObjectProtocol?

  init() {
    SettingKey.registerDefaults()
    // DISABLE APP NAP: This ensures the StateManager timer doesn't stop
    // when the app is in the background.
    self.activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .background],
      reason: "SuperZen Timer and Wellness Reminders"
    )
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

  @AppStorage(SettingKey.menuBarDisplay) var menuBarDisplay = "Icon and text"
  @AppStorage(SettingKey.timerStyle) var timerStyle = "15:11"

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
        timerStyle: timerStyle
      )
    }
  }
}

private struct MenuBarContentView: View {
  @ObservedObject var stateManager: StateManager

  var body: some View {
    VStack {
      if stateManager.dayProgressEnabled && stateManager.dayProgressPercent > 0 {
        VStack(alignment: .leading, spacing: 2) {
          Text("\(Int(stateManager.dayProgressPercent * 100))% of workday")
            .font(.headline)
          Text(formatTimeRemaining(stateManager.dayProgressTimeRemaining) + " until end of day")
            .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        Divider()
      }

      Text(
        "SuperZen: \(stateManager.isScheduleSleeping ? "Sleeping (scheduled)" : stateManager.status.description)"
      )

      Divider()

      Button("Start Break Now") {
        stateManager.transition(to: .onBreak)
      }

      Button(stateManager.status.isPaused ? "Resume" : "Pause") {
        stateManager.togglePause()
      }

      Divider()

      Button("Settings & Dashboard...") {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
          $0.identifier?.rawValue == "main" || $0.title == "SuperZen"
        }) {
          window.center()
          window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first {
          window.center()
          window.makeKeyAndOrderFront(nil)
        }
      }

      Button("Quit SuperZen") {
        NSApplication.shared.terminate(nil)
      }
    }
  }
}

private struct MenuBarLabelView: View {
  @ObservedObject var stateManager: StateManager
  let menuBarDisplay: String
  let timerStyle: String

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
          HStack(spacing: 6) {
            DayProgressPill(progress: stateManager.dayProgressPercent)
            Text("\(Int(stateManager.dayProgressPercent * 100))%")
              .font(.system(size: 12, weight: .medium, design: .rounded))
          }
        } else {
          Text(
            stateManager.isScheduleSleeping
              ? "Sleeping..." : stateManager.showTypingIndicator ? "Typing" : formattedTimerString
          )
        }
      }
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

private struct DayProgressPill: View {
  let progress: Double

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.15)).frame(height: 10)
        Capsule().fill(.white.opacity(0.85))
          .frame(width: max(10, geo.size.width * progress), height: 10)
      }
    }
    .frame(width: 36, height: 10)
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
