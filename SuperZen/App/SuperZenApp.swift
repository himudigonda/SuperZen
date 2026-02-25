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

  var body: some Scene {
    // Main Dashboard window
    WindowGroup("SuperZen") {
      ContentView()
        .environmentObject(stateManager)
        .modelContainer(sharedModelContainer)
        .onAppear {
          TelemetryService.shared.setup(context: sharedModelContainer.mainContext)
        }
    }
    .windowResizability(.contentSize)

    // Settings window — opened via menu bar
    Window("Settings", id: "settings") {
      SettingsView()
        .environmentObject(stateManager)
    }
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

        Button("Settings...") {
          NSApp.activate(ignoringOtherApps: true)
          if let settingsWindow = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "settings"
          }) {
            settingsWindow.makeKeyAndOrderFront(nil)
          } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
          }
        }

        Button("Quit SuperZen") {
          NSApplication.shared.terminate(nil)
        }
      }
    } label: {
      HStack {
        Image(systemName: stateManager.status == .onBreak ? "eye.slash.fill" : "eye.circle.fill")
        if stateManager.status == .nudge {
          Text("\(Int(stateManager.timeRemaining))s")
        }
      }
    }
  }
}
