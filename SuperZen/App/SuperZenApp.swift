import AppKit
import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager()

  // Local SwiftData container — all telemetry stays on-device
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
          WellnessManager.shared.start()
        }
    }
    .windowStyle(.hiddenTitleBar)  // Hides the ugly white Apple title bar
    .windowResizability(.contentSize)

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
          // Look for windows by ID or title if identifier check is tricky
          if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "main" || $0.title == "SuperZen"
          }) {
            window.makeKeyAndOrderFront(nil)
          } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
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

  // Logic to format the timer based on "Timer style" setting
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
