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
      // swiftlint:disable:next trailing_comma
      BreakEvent.self,
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
      ContentView()
        .environmentObject(stateManager)
        .modelContainer(sharedModelContainer)
        .onAppear {
          TelemetryService.shared.setup(context: sharedModelContainer.mainContext)
          stateManager.start()
        }
    }
    .windowStyle(.hiddenTitleBar)  // Hides the ugly white Apple title bar
    .windowResizability(.automatic)

    // Menu Bar Icon
    MenuBarExtra {
      VStack {
        Text("SuperZen: \(stateManager.status.description)")

        Divider()

        Button("Start Break Now") {
          stateManager.transition(to: .onBreak)
        }

        Button(stateManager.status.isPaused ? "Resume" : "Pause") {
          stateManager.togglePause()
        }

        Divider()

        // Update the button to just open the Main window
        Button("Settings & Dashboard...") {
          NSApp.activate(ignoringOtherApps: true)
          // Center the main window on the active screen before showing it
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
    } label: {
      HStack(spacing: 4) {
        // 1. Respect "Icon" settings
        if menuBarDisplay.contains("Icon") {
          Image(systemName: stateManager.status == .onBreak ? "eye.slash.fill" : "eye.circle.fill")
        }

        // 2. Respect "Text" and "Style" settings
        if menuBarDisplay.contains("text") || menuBarDisplay == "Text only" {
          Text(formattedTimerString)
        }
      }
    }
  }

  /// Logic to format the timer based on "Timer style" setting
  private var formattedTimerString: String {
    let totalSeconds = Int(max(0, stateManager.timeRemaining))
    let mins = totalSeconds / 60
    let secs = totalSeconds % 60

    switch timerStyle {
    case "15m":
      return "\(mins)m"
    case "15":
      return "\(mins)"
    default:  // "15:11"
      return String(format: "%d:%02d", mins, secs)
    }
  }
}
