import AppKit
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager()

  var body: some Scene {
    // Main Dashboard / Settings window
    WindowGroup("SuperZen") {
      ContentView()
        .environmentObject(stateManager)
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
          // Find the settings window by identifier and bring it forward
          if let settingsWindow = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "settings"
          }) {
            settingsWindow.makeKeyAndOrderFront(nil)
          } else {
            // Fallback: open the main window
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
